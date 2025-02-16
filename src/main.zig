const std = @import("std");
const math = std.math;
const rand = std.rand;

const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;
const Matrix = rl.Matrix;

const draw = @import("draw.zig");
const Line = draw.Line;
const Game = @import("game.zig").Game;
const Rocket = @import("rocket.zig").Rocket;
const Ship = @import("ship.zig").Ship;
const Asteroid = @import("asteroid.zig").Asteroid;
const Alien = @import("alien.zig").Alien;

fn updateRockets(
    rockets: *std.ArrayList(Rocket),
    game: *const Game,
    asteroids: *std.ArrayList(Asteroid),
    rnd: *rand.DefaultPrng,
) !void {
    var i: usize = 0;

    while (i < rockets.items.len) {
        if (!try rockets.items[i].update(game, asteroids, rnd)) {
            _ = rockets.swapRemove(i);
            continue;
        }

        i += 1;
    }
}

fn update(
    game: *const Game,
    ship: *Ship,
    asteroids: *std.ArrayList(Asteroid),
    rockets: *std.ArrayList(Rocket),
    rnd: *rand.DefaultPrng,
) !void {
    try ship.update(game);
    try updateRockets(rockets, game, asteroids, rnd);

    var i: usize = 0;

    while (i < asteroids.items.len) {
        if (asteroids.items[i].update(game, ship, rnd)) {
            if (asteroids.items.len > Asteroid.min_asteroids) {
                _ = asteroids.swapRemove(i);
                continue;
            }

            asteroids.items[i] = Asteroid.new(game, rnd);
        }

        i += 1;
    }
}

pub fn shoot(
    rockets: *std.ArrayList(Rocket),
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

    if (rockets.items.len == Rocket.max_rockets or
        static.timeSinceLastShot() < time_between_shots)
    {
        return;
    }

    try rockets.append(Rocket.new(ship_pos, ship_rot));

    static.setTime();
}

fn input(ship: *Ship, rockets: *std.ArrayList(Rocket)) !void {
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
        try shoot(rockets, ship.pos, ship.rot);
    }
}

fn drawRockets(rockets: *const std.ArrayList(Rocket)) void {
    const rocket_lenght = 3.0;

    for (rockets.items) |rocket| {
        var line: Line = .{
            .point_a = .{ .x = 0, .y = rocket_lenght / 2.0 },
            .point_b = .{ .x = 0, .y = -rocket_lenght / 2.0 },
        };

        line.point_a = line.point_a.rotate(rocket.angle);
        line.point_b = line.point_b.rotate(rocket.angle);
        line.point_a = line.point_a.add(rocket.pos);
        line.point_b = line.point_b.add(rocket.pos);

        draw.drawLine(line);
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

fn drawAlien() void {
    for (Alien.alien_default_lines) |line| {
        draw.drawLine(line);
    }
}

pub fn main() !void {
    rl.setConfigFlags(.{ .vsync_hint = true });

    // rl.initWindow(Game.window_width, Game.window_height, "Asteroids");
    // defer rl.closeWindow();

    rl.initWindow(rl.getScreenWidth(), rl.getScreenHeight(), "Asteroids");
    defer rl.closeWindow();
    rl.toggleFullscreen();

    rl.setTargetFPS(60);

    Asteroid.initStruct();

    const max_asteroids = 60;
    const min_asteroids = 25;

    var rnd = rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));

    var game = Game.new();
    var ship = Ship.new();
    var asteroids = try std.ArrayList(Asteroid).initCapacity(
        std.heap.page_allocator,
        max_asteroids,
    );
    var rockets = try std.ArrayList(Rocket).initCapacity(
        std.heap.page_allocator,
        Rocket.max_rockets,
    );

    for (0..min_asteroids) |_| {
        try asteroids.append(Asteroid.new(&game, &rnd));
    }

    // Detect window close button or ESC key
    while (!rl.windowShouldClose()) {
        game.delta_time = rl.getFrameTime();

        try input(&ship, &rockets);
        try update(&game, &ship, &asteroids, &rockets, &rnd);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        ship.draw();
        drawRockets(&rockets);
        drawAsteroids(&asteroids);
        drawAlien();
    }

    asteroids.deinit();
    rockets.deinit();
}
