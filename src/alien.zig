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

    pub const collision_radius = 6.0;
    const velocity = 1;

    health: i32,
    pos: Vector2,
    vel: Vector2,
    last_time_speed_updated: f64,
    last_time_projectile_shot: f64,
    projectile: ?Projectile,

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

        if (self.pos.x - bounds.left_bound <= min_distance_from_bounds) {
            multiply_x_by_1_or_minus_1 = 1;
        } else if (bounds.right_bound - self.pos.x <= min_distance_from_bounds) {
            multiply_x_by_1_or_minus_1 = -1;
        }

        if (self.pos.y - bounds.top_bound <= min_distance_from_bounds) {
            multiply_y_by_1_or_minus_1 = 1;
        } else if (bounds.bottom_bound - self.pos.x <= min_distance_from_bounds) {
            multiply_y_by_1_or_minus_1 = -1;
        }

        const flt = prng.random().float(f32);
        self.vel = Vector2.init(
            multiply_x_by_1_or_minus_1 * flt * velocity,
            multiply_y_by_1_or_minus_1 * (1 - flt) * velocity,
        );
    }

    pub fn new(bounds: Bounds, prng: *rand.DefaultPrng) Alien {
        var alien: Alien = .{
            .health = 100,
            .pos = Vector2.init(0, 0),
            .vel = Vector2.init(0, 0),
            .last_time_speed_updated = rl.getTime(),
            .last_time_projectile_shot = rl.getTime(),
            .projectile = null,
        };

        alien.projectile = Projectile.new(
            alien.pos,
            std.math.atan2(alien.vel.y, alien.vel.x),
        );

        alien.setRandomVel(bounds, prng);
        return alien;
    }

    /// Returns true if the alien should be destroyed
    pub fn update(self: *Alien, bounds: Bounds, prng: *rand.DefaultPrng) bool {
        const update_velocities_time = 2.0;

        if (self.health <= 0) {
            return true;
        }

        if (rl.getTime() - self.last_time_speed_updated >= update_velocities_time) {
            self.setRandomVel(bounds, prng);
            self.last_time_speed_updated = rl.getTime();
        }

        self.pos.x += self.vel.x * Game.deltaTimeNormalized();
        self.pos.y += self.vel.y * Game.deltaTimeNormalized();
        return false;
    }

    pub fn takeHit(self: *Alien) void {
        self.health -= 25;
    }
};
