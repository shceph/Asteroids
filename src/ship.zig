const std = @import("std");
const rand = std.rand;
const math = std.math;

const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;
const Matrix = rl.Matrix;

const draw_mod = @import("draw.zig");
const Line = draw_mod.Line;
const Rocket = @import("rocket.zig").Rocket;
const Game = @import("game.zig").Game;
const Asteroid = @import("asteroid.zig").Asteroid;

fn convertFromGameToWindowCoords(vec: Vector2, game: *const Game) Vector2 {
    var result: Vector2 = undefined;
    result.x = (vec.x + game.bounds.right_bound) * game.win_width_over_game_width;
    result.y = (vec.y + game.bounds.bottom_bound) * game.win_height_over_game_height;
    return result;
}

const gameToWin = convertFromGameToWindowCoords;

pub const Ship = struct {
    const default_ship_lines: [7]Line = .{
        .{ .point_a = .{ .x = 0.00, .y = 5.00 }, .point_b = .{ .x = -5.0, .y = -5.0 } },
        .{ .point_a = .{ .x = 0.00, .y = 5.00 }, .point_b = .{ .x = 5.00, .y = -5.0 } },
        .{ .point_a = .{ .x = -5.0, .y = -5.0 }, .point_b = .{ .x = -3.0, .y = -3.5 } },
        .{ .point_a = .{ .x = 5.00, .y = -5.0 }, .point_b = .{ .x = 3.00, .y = -3.5 } },
        .{ .point_a = .{ .x = -3.0, .y = -3.5 }, .point_b = .{ .x = 3.00, .y = -3.5 } },
        .{ .point_a = .{ .x = -2.0, .y = -3.5 }, .point_b = .{ .x = 0.00, .y = -7.0 } },
        .{ .point_a = .{ .x = 2.00, .y = -3.5 }, .point_b = .{ .x = 0.00, .y = -7.0 } },
    };

    const max_velocity = 3;
    const engine_working_acc = 0.07;
    const engine_idle_drag = 0.014;
    const rotation_speed = 4.0;
    const max_rockets = 5;

    ship_lines: [7]Line,
    pos: Vector2,
    vel: Vector2,
    acc: Vector2,
    rot: f32,
    angle_when_engine_last_used: f32,
    engine_working: bool,
    collided: bool,
    rotate_leftwards: bool,
    rotate_rightwards: bool,

    const shipLinesRandVelocities = struct {
        var vels: [7]Vector2 = undefined;

        fn setRandVelocities(rnd: *rand.DefaultPrng) void {
            for (&vels) |*value| {
                value.x = (rnd.random().float(f32) - 0.5);
                value.y = (rnd.random().float(f32) - 0.5);
            }
        }
    };

    const lineVels = shipLinesRandVelocities;

    pub fn new() Ship {
        const ship: Ship = .{
            .pos = rl.Vector2.init(0, 0),
            .vel = rl.Vector2.init(0, 0),
            .acc = rl.Vector2.init(0, 0),
            .rot = 0,
            .angle_when_engine_last_used = 0,
            .engine_working = false,
            .collided = false,
            .rotate_leftwards = false,
            .rotate_rightwards = false,
            .ship_lines = default_ship_lines,
        };

        return ship;
    }

    pub fn realive(self: *Ship) void {
        self.* = Ship.new();
    }

    pub fn hasCollided(self: *Ship, rnd: *rand.DefaultPrng) void {
        if (self.collided) {
            return;
        }

        self.collided = true;
        self.acc = .{ .x = 0, .y = 0 };
        // self.vel = .{ .x = 0, .y = 0 };
        self.engine_working = false;
        lineVels.setRandVelocities(rnd);
    }

    pub fn rotateLeftwards(self: *Ship) void {
        self.rotate_leftwards = true;
    }

    pub fn rotateRightwards(self: *Ship) void {
        self.rotate_rightwards = true;
    }

    pub fn update(self: *Ship, game: *const Game) !void {
        if (self.rotate_leftwards) {
            self.rot -=
                math.degreesToRadians(rotation_speed) * game.deltaTimeNormalized();
            self.rotate_leftwards = false;
        }

        if (self.rotate_rightwards) {
            self.rot +=
                math.degreesToRadians(rotation_speed) * game.deltaTimeNormalized();
            self.rotate_rightwards = false;
        }

        if (self.collided) {
            for (&self.ship_lines, 0..) |*line, i| {
                line.point_a =
                    line.point_a.add(lineVels.vels[i].scale(game.deltaTimeNormalized()));
                line.point_b =
                    line.point_b.add(lineVels.vels[i].scale(game.deltaTimeNormalized()));
            }
        } else if (self.engine_working) {
            self.acc.x = @sin(-self.rot) * engine_working_acc;
            self.acc.y = @cos(self.rot) * engine_working_acc;
        } else {
            if (self.vel.x > engine_idle_drag or self.vel.x < -engine_idle_drag) {
                self.acc.x = -engine_idle_drag * @cos(self.angle_when_engine_last_used);
            } else {
                self.acc.x = 0;
            }

            if (self.vel.y > engine_idle_drag or self.vel.y < -engine_idle_drag) {
                self.acc.y = -engine_idle_drag * @sin(self.angle_when_engine_last_used);
            } else {
                self.acc.y = 0;
            }
        }

        const is_at_max_vel =
            (math.pow(f32, self.vel.x, 2) + math.pow(f32, self.vel.y, 2) >= Ship.max_velocity * Ship.max_velocity);

        const apply_acceleration_condition = !(is_at_max_vel and
            (@abs(self.vel.x + self.acc.x * 0.5) > @abs(self.vel.x) or
            @abs(self.vel.y + self.acc.y * 0.5) > @abs(self.vel.y)));

        if (apply_acceleration_condition) {
            self.vel.x += self.acc.x * 0.5 * game.deltaTimeNormalized();
            self.vel.y += self.acc.y * 0.5 * game.deltaTimeNormalized();
        }

        self.pos.x += self.vel.x * game.deltaTimeNormalized();
        self.pos.y += self.vel.y * game.deltaTimeNormalized();

        if (apply_acceleration_condition) {
            self.vel.x += self.acc.x * 0.5 * game.deltaTimeNormalized();
            self.vel.y += self.acc.y * 0.5 * game.deltaTimeNormalized();
        }

        if (self.collided) {
            return;
        }

        if (self.pos.x < game.bounds.left_bound) {
            self.pos.x = game.bounds.right_bound;
        }

        if (self.pos.x > game.bounds.right_bound) {
            self.pos.x = game.bounds.left_bound;
        }

        if (self.pos.y < game.bounds.top_bound) {
            self.pos.y = game.bounds.bottom_bound;
        }

        if (self.pos.y > game.bounds.bottom_bound) {
            self.pos.y = game.bounds.top_bound;
        }
    }

    pub fn shoot(self: *Ship) !void {
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

        if (self.rockets.items.len == max_rockets or
            static.timeSinceLastShot() < time_between_shots)
        {
            return;
        }

        try self.rockets.append(Rocket.new(self.pos, self.rot));

        static.setTime();
    }

    pub fn draw(self: *Ship) void {
        const frameCount = struct {
            var frame_count: i32 = 0;
            var draw_fire: bool = true;

            fn update() void {
                frame_count += 1;

                if (frame_count == 3) {
                    frame_count = 0;
                    draw_fire = !draw_fire;
                }
            }
        };

        frameCount.update();

        var ship_lines: [7]Line = undefined;
        std.mem.copyForwards(Line, &ship_lines, self.ship_lines[0..]);

        for (&ship_lines) |*line| {
            line.point_a = self.pos.add(rlm.vector2Rotate(line.point_a, self.rot));
            line.point_b = self.pos.add(rlm.vector2Rotate(line.point_b, self.rot));
        }

        for (ship_lines[0..5]) |line| {
            draw_mod.drawLine(line);
        }

        if (self.engine_working and frameCount.draw_fire) {
            draw_mod.drawLine(ship_lines[5]);
            draw_mod.drawLine(ship_lines[6]);
        }
    }
};
