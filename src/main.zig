const std = @import("std");
const math = std.math;
const rand = std.rand;

const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;
const Matrix = rl.Matrix;

const draw = @import("draw.zig");
const sounds = @import("sound.zig").sounds;
const Line = draw.Line;
const Game = @import("game.zig").Game;
const Projectile = @import("projectile.zig").Projectile;
const Ship = @import("ship.zig").Ship;
const Asteroid = @import("asteroid.zig").Asteroid;
const Alien = @import("alien.zig").Alien;

fn updateProjectiles(
    projectiles: *std.ArrayList(Projectile),
    game: *const Game,
    ship: *Ship,
    asteroids: *std.ArrayList(Asteroid),
    aliens: []Alien,
    prng: *rand.DefaultPrng,
) !void {
    var i: usize = 0;

    while (i < projectiles.items.len) {
        if (try projectiles.items[i].update(
            game.bounds,
            ship,
            asteroids,
            aliens,
            prng,
        )) {
            _ = projectiles.swapRemove(i);
            continue;
        }

        i += 1;
    }
}

fn updateAlienProjectiles(
    aliens: []Alien,
    bounds: Game.Bounds,
    ship: *Ship,
    asteroids: *std.ArrayList(Asteroid),
    prng: *rand.DefaultPrng,
) !void {
    for (aliens) |*alien| {
        if (alien.projectile) |*projectile| {
            const alien_projectile_should_be_destroyed = try projectile.update(
                bounds,
                ship,
                asteroids,
                aliens,
                prng,
            );

            if (alien_projectile_should_be_destroyed) {
                alien.projectile = null;
            }
        }

        const time_between_shots = 4.0;
        const can_shoot_projectile_again =
            rl.getTime() - alien.last_time_projectile_shot >= time_between_shots;

        if (alien.projectile == null and can_shoot_projectile_again) {
            const alien_to_ship_vec = rlm.vector2Subtract(ship.pos, alien.pos);
            alien.projectile = Projectile.new(
                alien.pos,
                math.atan2(alien_to_ship_vec.y, alien_to_ship_vec.x),
            );

            alien.last_time_projectile_shot = rl.getTime();
            rl.playSound(sounds.alien_shooting);
        }
    }
}

fn update(
    game: *const Game,
    ship: *Ship,
    asteroids: *std.ArrayList(Asteroid),
    projectiles: *std.ArrayList(Projectile),
    aliens: *std.BoundedArray(Alien, 3),
    prng: *rand.DefaultPrng,
) !void {
    if (ship.has_collided_this_frame) {
        rl.playSound(sounds.ship_destroyed);
    }

    try ship.update(game.bounds);
    try updateProjectiles(projectiles, game, ship, asteroids, aliens.slice(), prng);
    try updateAlienProjectiles(aliens.slice(), game.bounds, ship, asteroids, prng);

    var i: usize = 0;
    while (i < aliens.len) {
        const destroy_alien = aliens.slice()[i].update(game.bounds, prng);

        if (!destroy_alien) {
            i += 1;
            continue;
        }

        _ = aliens.swapRemove(i);
    }

    i = 0;
    while (i < asteroids.items.len) {
        const destroy_asteroid = asteroids.items[i].update(
            game.bounds,
            ship,
            prng,
        );

        if (!destroy_asteroid) {
            i += 1;
            continue;
        }

        if (asteroids.items.len > Asteroid.min_asteroids) {
            _ = asteroids.swapRemove(i);
        } else {
            asteroids.items[i] = Asteroid.new(game.bounds, prng);
        }
    }
}

pub fn shoot(
    projectiles: *std.ArrayList(Projectile),
    ship_pos: Vector2,
    ship_rot: f32,
) !void {
    const static = struct {
        var time_up_to_last_shot: f64 = 0;

        fn setTime() void {
            time_up_to_last_shot = rl.getTime();
        }

        fn timeSinceLastShot() f64 {
            return rl.getTime() - time_up_to_last_shot;
        }
    };

    const time_between_shots = 0.1;

    if (projectiles.items.len == Projectile.max_projectiles or
        static.timeSinceLastShot() < time_between_shots)
    {
        return;
    }

    try projectiles.append(Projectile.new(ship_pos, ship_rot));
    rl.playSound(sounds.ship_shooting);

    static.setTime();
}

fn input(ship: *Ship, projectiles: *std.ArrayList(Projectile)) !void {
    if (ship.collided) {
        if (rl.isKeyDown(.enter)) {
            ship.realive();
        }

        return;
    }

    if (rl.isKeyDown(.left)) {
        ship.rotateLeftwards();
    } else if (rl.isKeyDown(.right)) {
        ship.rotateRightwards();
    }

    if (rl.isKeyDown(.up)) {
        ship.engine_working = true;
    } else if (rl.isKeyReleased(.up)) {
        ship.angle_when_engine_last_used = math.atan2(ship.vel.y, ship.vel.x);
        ship.engine_working = false;
    } else {
        ship.engine_working = false;
    }

    if (rl.isKeyDown(.space)) {
        try shoot(projectiles, ship.pos, ship.rot);
    }
}

fn drawProjectiles(
    projectiles: *const std.ArrayList(Projectile),
    aliens: []Alien,
) void {
    const projectile_lenght = 3.0;

    for (projectiles.items) |projectile| {
        var line: Line = .{
            .point_a = .{ .y = 0, .x = projectile_lenght / 2.0 },
            .point_b = .{ .y = 0, .x = -projectile_lenght / 2.0 },
        };

        line.point_a = line.point_a.rotate(projectile.angle);
        line.point_b = line.point_b.rotate(projectile.angle);
        line.point_a = line.point_a.add(projectile.pos);
        line.point_b = line.point_b.add(projectile.pos);

        draw.drawLine(line);
    }

    for (aliens) |alien| {
        if (alien.projectile) |projectile| {
            var line: Line = .{
                .point_a = .{ .y = 0, .x = projectile_lenght / 2.0 },
                .point_b = .{ .y = 0, .x = -projectile_lenght / 2.0 },
            };

            line.point_a = line.point_a.rotate(projectile.angle);
            line.point_b = line.point_b.rotate(projectile.angle);
            line.point_a = line.point_a.add(projectile.pos);
            line.point_b = line.point_b.add(projectile.pos);

            draw.drawLine(line);
        }
    }
}

fn drawAsteroids(asteroids: *const std.ArrayList(Asteroid)) void {
    for (asteroids.items) |astr| {
        for (0..astr.points.len - 1) |i| {
            const point_a = astr.pos.add(astr.points[i]);
            const point_b = astr.pos.add(astr.points[i + 1]);
            draw.drawLineVec2(point_a, point_b);
        }

        const point_a = astr.pos.add(astr.points[0]);
        const point_b = astr.pos.add(astr.points[astr.points.len - 1]);
        draw.drawLineVec2(point_a, point_b);
    }
}

fn drawAliens(aliens: []Alien) void {
    for (aliens) |alien| {
        for (Alien.alien_default_lines) |line| {
            draw.drawLineVec2(
                rlm.vector2Add(line.point_a, alien.pos),
                rlm.vector2Add(line.point_b, alien.pos),
            );
        }
    }
}

pub fn main() !void {
    rl.setConfigFlags(.{ .vsync_hint = true });

    rl.initWindow(Game.window_width, Game.window_height, "Asteroids");
    defer rl.closeWindow();

    // rl.initWindow(rl.getScreenWidth(), rl.getScreenHeight(), "Asteroids");
    // defer rl.closeWindow();
    // rl.toggleFullscreen();

    rl.initAudioDevice();
    defer rl.closeAudioDevice();
    try sounds.initSounds();

    rl.setTargetFPS(60);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            rl.traceLog(.err, "GPA memory leaked", .{});
        }
    }
    const allocator = gpa.allocator();

    Asteroid.initStruct();

    const alien_count = 3;

    var prng = rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));

    var game = Game.new();
    var ship = Ship.new();

    var aliens = try std.BoundedArray(Alien, alien_count).init(0);

    for (0..alien_count) |_| {
        try aliens.append(Alien.new(game.bounds, &prng));
    }

    var asteroids = try std.ArrayList(Asteroid).initCapacity(
        allocator,
        Asteroid.max_asteroids,
    );
    defer asteroids.deinit();

    var projectiles = try std.ArrayList(Projectile).initCapacity(
        allocator,
        Projectile.max_projectiles,
    );
    defer projectiles.deinit();

    for (0..Asteroid.min_asteroids) |_| {
        try asteroids.append(Asteroid.new(game.bounds, &prng));
    }

    // Detect window close button or ESC key
    while (!rl.windowShouldClose()) {
        try input(&ship, &projectiles);
        try update(&game, &ship, &asteroids, &projectiles, &aliens, &prng);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        ship.draw();
        drawProjectiles(&projectiles, aliens.slice());
        drawAsteroids(&asteroids);
        drawAliens(aliens.slice());
    }
}
