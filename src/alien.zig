const std = @import("std");
const rand = std.rand;

const rl = @import("raylib");
const Vector2 = rl.Vector2;

const Game = @import("game.zig").Game;
const Projectile = @import("projectile.zig").Projectile;
const Line = @import("draw.zig").Line;
const Bounds = @import("game.zig").Game.Bounds;

pub const Alien = struct {
    pub const alien_default_lines: [10]Line = .{
        .{ .point_a = .{ .x = -10.0, .y = 0.0 }, .point_b = .{ .x = 10.0, .y = 0.0 } },
        .{ .point_a = .{ .x = -8.0, .y = 0.0 }, .point_b = .{ .x = -6.0, .y = 2.0 } },
        .{ .point_a = .{ .x = 8.0, .y = 0.0 }, .point_b = .{ .x = 6.0, .y = 2.0 } },
        .{ .point_a = .{ .x = -6.0, .y = 2.0 }, .point_b = .{ .x = 6.0, .y = 2.0 } },

        .{ .point_a = .{ .x = -10.0, .y = 0.0 }, .point_b = .{ .x = -8.0, .y = -4.0 } },
        .{ .point_a = .{ .x = 10.0, .y = 0.0 }, .point_b = .{ .x = 8.0, .y = -4.0 } },

        .{ .point_a = .{ .x = -8.0, .y = -4.0 }, .point_b = .{ .x = 8.0, .y = -4.0 } },
        .{ .point_a = .{ .x = -4.0, .y = -4.0 }, .point_b = .{ .x = -2.0, .y = -6.0 } },
        .{ .point_a = .{ .x = 4.0, .y = -4.0 }, .point_b = .{ .x = 2.0, .y = -6.0 } },
        .{ .point_a = .{ .x = -2.0, .y = -6.0 }, .point_b = .{ .x = 2.0, .y = -6.0 } },
    };

    const velocity = 1;

    pos: Vector2,
    vel: Vector2,
    projectile: Projectile,

    pub fn setRandomVel(
        self: *Alien,
        bounds: Bounds,
        prng: *rand.DefaultPrng,
    ) void {
        var multiply_x_by_1_or_minus_1: f32 =
            if (prng.random().boolean()) -1 else 1;

        var multiply_y_by_1_or_minus_1: f32 =
            if (prng.random().boolean()) -1 else 1;

        const min_distance_from_bounds = 20;

        if (@abs(self.pos.x - bounds.left_bound) <= min_distance_from_bounds) {
            multiply_x_by_1_or_minus_1 = 1;
            std.debug.print("\nleft bound\n", .{});
        } else if (@abs(self.pos.x - bounds.right_bound) <= min_distance_from_bounds) {
            multiply_x_by_1_or_minus_1 = -1;
            std.debug.print("\nright bound\n", .{});
        }

        if (@abs(self.pos.y - bounds.top_bound) <= min_distance_from_bounds) {
            multiply_y_by_1_or_minus_1 = 1;
            std.debug.print("\ntop bound\n", .{});
        } else if (@abs(self.pos.y - bounds.bottom_bound) <= min_distance_from_bounds) {
            multiply_y_by_1_or_minus_1 = -1;
            std.debug.print("\nbottom bound\n", .{});
        }

        const flt = prng.random().float(f32);
        self.vel = Vector2.init(
            multiply_x_by_1_or_minus_1 * flt * velocity,
            multiply_y_by_1_or_minus_1 * (1 - flt) * velocity,
        );
    }

    pub fn new(bounds: Bounds, prng: *rand.DefaultPrng) Alien {
        var alien: Alien = .{
            .pos = Vector2.init(0, 0),
            .vel = Vector2.init(0, 0),
            .projectile = undefined,
        };

        alien.projectile = Projectile.new(
            alien.pos,
            std.math.atan2(alien.vel.x, alien.vel.y),
        );

        alien.setRandomVel(bounds, prng);
        return alien;
    }

    pub fn update(self: *Alien, game: *const Game, prng: *rand.DefaultPrng) void {
        const static = struct {
            var frame_count: i32 = 0;

            fn update(
                alien: *Alien,
                bounds: Bounds,
                prng_inner: *rand.DefaultPrng,
            ) void {
                if (frame_count >= 120) {
                    alien.setRandomVel(bounds, prng_inner);
                    frame_count = 0;
                }

                frame_count += 1;
            }
        };

        static.update(self, game.bounds, prng);

        self.pos.x += self.vel.x * game.deltaTimeNormalized();
        self.pos.y += self.vel.y * game.deltaTimeNormalized();
    }
};
