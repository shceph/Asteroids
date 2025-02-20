const std = @import("std");
const rand = std.rand;
const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;

const Game = @import("game.zig").Game;
const Asteroid = @import("asteroid.zig").Asteroid;
const Ship = @import("ship.zig").Ship;

fn isPosInMap(pos: Vector2, game: *const Game) bool {
    if (pos.x < game.bounds.left_bound or pos.x > game.bounds.right_bound or
        pos.y < game.bounds.top_bound or pos.y > game.bounds.bottom_bound)
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

    /// If returned false, the projectile is to be destroyed
    pub fn update(
        self: *Projectile,
        game: *const Game,
        ship: *Ship,
        asteroids: *std.ArrayList(Asteroid),
        prng: *rand.DefaultPrng,
    ) !bool {
        self.pos.x += projectile_speed * @sin(-self.angle) * game.deltaTimeNormalized();
        self.pos.y += projectile_speed * @cos(self.angle) * game.deltaTimeNormalized();

        if (!isPosInMap(self.pos, game)) {
            return false;
        }

        if (rlm.vector2Distance(self.pos, ship.pos) < Ship.collision_radius) {
            ship.hasCollided(prng);
        }

        for (asteroids.items) |*astr| {
            if (rlm.vector2Distance(astr.pos, self.pos) <= Asteroid.radius(astr.size)) {
                if (astr.size == .small) {
                    astr.* = Asteroid.new(game, prng);
                    return false;
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

                return false;
            }
        }

        return true;
    }
};
