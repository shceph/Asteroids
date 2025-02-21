const std = @import("std");
const rand = std.rand;
const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;

const Game = @import("game.zig").Game;
const Asteroid = @import("asteroid.zig").Asteroid;
const Ship = @import("ship.zig").Ship;

fn isPosInMap(pos: Vector2, bounds: Game.Bounds) bool {
    if (pos.x < bounds.left_bound or pos.x > bounds.right_bound or
        pos.y < bounds.top_bound or pos.y > bounds.bottom_bound)
    {
        return false;
    }

    return true;
}

pub const Projectile = struct {
    pub const max_projectiles = 5;
    const projectile_speed = 4.0;

    pos: Vector2,
    angle: f32,

    pub fn new(pos: Vector2, angle: f32) Projectile {
        var projectile: Projectile = .{
            .pos = pos,
            .angle = angle,
        };

        projectile.pos.x += @cos(angle) * Ship.collision_radius;
        projectile.pos.y += @sin(angle) * Ship.collision_radius;

        return projectile;
    }

    /// If returned true, the projectile is to be destroyed
    pub fn update(
        self: *Projectile,
        bounds: Game.Bounds,
        ship: *Ship,
        asteroids: *std.ArrayList(Asteroid),
        prng: *rand.DefaultPrng,
    ) !bool {
        self.pos.x += projectile_speed * @cos(self.angle) * Game.deltaTimeNormalized();
        self.pos.y += projectile_speed * @sin(self.angle) * Game.deltaTimeNormalized();

        if (!isPosInMap(self.pos, bounds)) {
            return true;
        }

        if (rlm.vector2Distance(self.pos, ship.pos) < Ship.collision_radius) {
            ship.hasCollided(prng);
            return true;
        }

        for (asteroids.items) |*astr| {
            if (rlm.vector2Distance(astr.pos, self.pos) <= Asteroid.radius(astr.size)) {
                if (astr.size == .small) {
                    astr.* = Asteroid.new(bounds, prng);
                    return true;
                }

                const new_size: Asteroid.Size =
                    if (astr.size == .large) .medium else .small;
                const astr_pos = astr.pos;
                const astr_vel = astr.velocity;

                astr.* = Asteroid.newFromDestroyed(
                    astr_pos,
                    astr_vel,
                    new_size,
                    prng,
                );
                try asteroids.append(
                    Asteroid.newFromDestroyed(
                        astr_pos,
                        astr_vel,
                        new_size,
                        prng,
                    ),
                );

                return true;
            }
        }

        return false;
    }
};
