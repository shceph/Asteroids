const std = @import("std");
const rand = std.rand;
const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;

const Game = @import("game.zig").Game;
const Asteroid = @import("asteroid.zig").Asteroid;

fn isPosInMap(pos: Vector2, game: *const Game) bool {
    if (pos.x < game.bounds.left_bound or pos.x > game.bounds.right_bound or
        pos.y < game.bounds.top_bound or pos.y > game.bounds.bottom_bound)
    {
        return false;
    }

    return true;
}

pub const Rocket = struct {
    pub const max_rockets = 5;
    const rocket_speed = 4.0;

    pos: Vector2,
    angle: f32,

    pub fn new(pos: Vector2, angle: f32) Rocket {
        const rocket: Rocket = .{
            .pos = pos,
            .angle = angle,
        };
        return rocket;
    }

    /// If returned false, the rocket is to be destroyed
    pub fn update(
        self: *Rocket,
        game: *const Game,
        asteroids: *std.ArrayList(Asteroid),
        rnd: *rand.DefaultPrng,
    ) !bool {
        self.pos.x += rocket_speed * @sin(-self.angle) * game.*.deltaTimeNormalized();
        self.pos.y += rocket_speed * @cos(self.angle) * game.*.deltaTimeNormalized();

        if (!isPosInMap(self.pos, game)) {
            return false;
        }

        for (asteroids.items) |*astr| {
            if (rlm.vector2Distance(astr.pos, self.pos) <= Asteroid.radius(astr.size)) {
                if (astr.size == .small) {
                    astr.* = Asteroid.new(game, rnd);
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
                    rnd,
                );
                try asteroids.append(
                    Asteroid.newFromDestroyed(
                        astr_pos,
                        astr_vel,
                        new_size,
                        rnd,
                    ),
                );

                return false;
            }
        }

        return true;
    }
};
