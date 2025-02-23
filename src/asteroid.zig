const std = @import("std");
const math = std.math;
const rand = std.rand;

const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;
const Matrix = rl.Matrix;

const Game = @import("game.zig").Game;
const Ship = @import("ship.zig").Ship;

pub const Asteroid = struct {
    pub const min_asteroids = 10;
    pub const max_asteroids = 20;
    var points_on_circle_small_ast: [8]Vector2 = undefined;
    var points_on_circle_medium_ast: [8]Vector2 = undefined;
    var points_on_circle_large_ast: [8]Vector2 = undefined;

    points: [8]Vector2,
    pos: Vector2,
    velocity: Vector2,
    size: Size,
    spawn_side: SpawnSide,

    pub const Size = enum {
        small,
        medium,
        large,
    };

    const SpawnSide = enum {
        top,
        bottom,
        left,
        right,
        check_for_all,
    };

    pub fn radius(size: Size) f32 {
        return switch (size) {
            .small => 4,
            .medium => 8,
            .large => 12,
        };
    }

    fn randomMultiplier(size: Size) f32 {
        return switch (size) {
            .small => 1.8,
            .medium => 3.6,
            .large => 5.8,
        };
    }

    fn speedMultiplier(size: Size) f32 {
        return switch (size) {
            .small => 1.5,
            .medium => 1.0,
            .large => 0.8,
        };
    }

    fn pointsOnCircle(size: Size) *const [8]Vector2 {
        return switch (size) {
            .small => &points_on_circle_small_ast,
            .medium => &points_on_circle_medium_ast,
            .large => &points_on_circle_large_ast,
        };
    }

    pub fn initStruct() void {
        for (0..8) |i| {
            points_on_circle_small_ast[i] = .{
                .x = @cos(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.small),
                .y = @sin(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.small),
            };
            points_on_circle_medium_ast[i] = .{
                .x = @cos(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.medium),
                .y = @sin(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.medium),
            };
            points_on_circle_large_ast[i] = .{
                .x = @cos(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.large),
                .y = @sin(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.large),
            };
        }
    }

    pub fn new(bounds: Game.Bounds, prng: *rand.DefaultPrng) Asteroid {
        var astr: Asteroid = .{
            .points = undefined,
            .pos = undefined,
            .velocity = undefined,
            .size = undefined,
            .spawn_side = undefined,
        };

        const rand_int = @mod(prng.random().int(i32), 100);

        if (rand_int >= 90) {
            astr.size = .large;
        } else if (rand_int >= 20) {
            astr.size = .medium;
        } else {
            astr.size = .small;
        }

        astr.spawn_side = @enumFromInt(@mod(prng.random().int(i32), 4));

        if (astr.spawn_side == .top) {
            astr.pos.x = (prng.random().float(f32) - 0.5) *
                (bounds.right_bound + @abs(bounds.left_bound));
            astr.pos.y = bounds.top_bound - radius(astr.size);
            astr.velocity.x = (prng.random().float(f32) - 0.5) * 2;
            astr.velocity.y = (1 - astr.velocity.x);
        } else if (astr.spawn_side == .bottom) {
            astr.pos.x = (prng.random().float(f32) - 0.5) *
                (bounds.right_bound + @abs(bounds.left_bound));
            astr.pos.y = bounds.bottom_bound + radius(astr.size);
            astr.velocity.x = (prng.random().float(f32) - 0.5) * 2;
            astr.velocity.y = (1 - astr.velocity.x) * (-1);
        } else if (astr.spawn_side == .left) {
            astr.pos.x = bounds.left_bound - radius(astr.size);
            astr.pos.y = (prng.random().float(f32) - 0.5) *
                (bounds.bottom_bound + @abs(bounds.top_bound));
            astr.velocity.x = prng.random().float(f32);
            astr.velocity.y = (1 - astr.velocity.x);
        } else if (astr.spawn_side == .right) {
            astr.pos.x = bounds.right_bound + radius(astr.size);
            astr.pos.y = (prng.random().float(f32) - 0.5) *
                (bounds.bottom_bound + @abs(bounds.top_bound));
            astr.velocity.x = prng.random().float(f32) * (-1);
            astr.velocity.y = (1 - astr.velocity.x) * (-1);
        }

        astr.velocity.x *= speedMultiplier(astr.size);
        astr.velocity.y *= speedMultiplier(astr.size);

        for (astr.points, 0..) |_, i| {
            // The random number is always positive, and I don't want
            // coordinates to only increase since it would be weird when
            // checking for collision as center wouldn't really be in center
            const multiply_x_by_1_or_minus_1: f32 =
                if (prng.random().boolean()) -1 else 1;

            const multiply_y_by_1_or_minus_1: f32 =
                if (prng.random().boolean()) -1 else 1;

            astr.points[i].x =
                Asteroid.pointsOnCircle(astr.size)[i].x + multiply_x_by_1_or_minus_1 *
                prng.random().float(f32) * randomMultiplier(astr.size);

            astr.points[i].y =
                Asteroid.pointsOnCircle(astr.size)[i].y + multiply_y_by_1_or_minus_1 *
                prng.random().float(f32) * randomMultiplier(astr.size);
        }

        return astr;
    }

    pub fn newFromDestroyed(
        pos: Vector2,
        parentAstrVel: Vector2,
        size: Size,
        prng: *rand.DefaultPrng,
    ) Asteroid {
        var astr: Asteroid = .{
            .points = undefined,
            .pos = pos,
            .velocity = undefined,
            .size = size,
            .spawn_side = .check_for_all,
        };

        astr.velocity = parentAstrVel;
        astr.velocity.x += prng.random().float(f32) / 5;
        astr.velocity.y += (1.0 / 5.0) - astr.velocity.x;

        for (astr.points, 0..) |_, i| {
            const multiply_x_by_1_or_minus_1: f32 =
                if (prng.random().boolean()) -1 else 1;

            const multiply_y_by_1_or_minus_1: f32 =
                if (prng.random().boolean()) -1 else 1;

            astr.points[i].x =
                Asteroid.pointsOnCircle(astr.size)[i].x +
                multiply_x_by_1_or_minus_1 * prng.random().float(f32) *
                randomMultiplier(astr.size);

            astr.points[i].y =
                Asteroid.pointsOnCircle(astr.size)[i].y +
                multiply_y_by_1_or_minus_1 * prng.random().float(f32) *
                randomMultiplier(astr.size);
        }

        return astr;
    }

    fn checkIfOutOfBounds(
        self: *Asteroid,
        bounds: Game.Bounds,
        top: bool,
        bottom: bool,
        left: bool,
        right: bool,
    ) bool {
        if ((top and self.pos.y < bounds.top_bound) or
            (bottom and self.pos.y > bounds.bottom_bound) or
            (left and self.pos.x < bounds.left_bound) or
            (right and self.pos.x > bounds.right_bound))
        {
            return true;
        }

        return false;
    }

    /// Returns true if the asteroid should be destroyed
    pub fn update(
        self: *Asteroid,
        bounds: Game.Bounds,
        ship: *Ship,
        prng: *rand.DefaultPrng,
    ) bool {
        self.pos.x += self.velocity.x * Game.deltaTimeNormalized();
        self.pos.y += self.velocity.y * Game.deltaTimeNormalized();

        if (rlm.vector2Distance(self.pos, ship.pos) <= radius(self.size)) {
            ship.hasCollided(prng);
        }

        if ((self.spawn_side == .top and self.checkIfOutOfBounds(
            bounds,
            false,
            true,
            true,
            true,
        )) or
            (self.spawn_side == .bottom and self.checkIfOutOfBounds(
            bounds,
            true,
            false,
            true,
            true,
        )) or
            (self.spawn_side == .left and self.checkIfOutOfBounds(
            bounds,
            true,
            true,
            false,
            true,
        )) or
            (self.spawn_side == .right and self.checkIfOutOfBounds(
            bounds,
            true,
            true,
            true,
            false,
        )) or
            (self.spawn_side == .check_for_all and self.checkIfOutOfBounds(
            bounds,
            true,
            true,
            true,
            true,
        ))) {
            return true;
        }

        return false;
    }
};
