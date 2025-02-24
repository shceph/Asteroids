const std = @import("std");
const rand = std.rand;

const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;

const draw_mod = @import("draw.zig");

pub const Particles = struct {
    asteroid_particles: std.ArrayList(AsteroidParticles),

    pub fn init(allocator: std.mem.Allocator) Particles {
        const particles = Particles{
            .asteroid_particles = std.ArrayList(AsteroidParticles).init(allocator),
        };
        return particles;
    }

    pub fn deinit(self: Particles) void {
        self.asteroid_particles.deinit();
    }

    pub fn beginParticles(
        self: *Particles,
        begin_pos: Vector2,
        lifetime_duration_in_sec: f32,
        prng: *rand.DefaultPrng,
    ) !void {
        try self.asteroid_particles.append(
            AsteroidParticles.new(
                begin_pos,
                lifetime_duration_in_sec,
                prng,
            ),
        );
    }

    pub fn update(self: *Particles) void {
        var i: usize = 0;

        while (i < self.asteroid_particles.items.len) {
            const should_destroy_particles =
                self.asteroid_particles.items[i].update();

            if (should_destroy_particles) {
                _ = self.asteroid_particles.swapRemove(i);
                continue;
            }

            i += 1;
        }
    }

    pub fn draw(self: Particles) void {
        for (self.asteroid_particles.items) |particles| {
            particles.draw();
        }
    }
};

const AsteroidParticles = struct {
    const particleCount = 8;
    const particleSpeed = 0.4;

    points: [particleCount]Vector2,
    velocities: [particleCount]Vector2,
    time_of_creation: f64,
    lifetime_duration_sec: f32,

    fn new(
        begin_pos: Vector2,
        lifetime_duration_in_sec: f32,
        prng: *rand.DefaultPrng,
    ) AsteroidParticles {
        var ast_particles: AsteroidParticles = undefined;
        const rnd = prng.random();

        for (&ast_particles.points) |*point| {
            point.* = begin_pos;
        }

        for (&ast_particles.velocities) |*vel| {
            const rand_float = rnd.float(f32);
            vel.x = rand_float * particleSpeed;
            vel.y = (1 - rand_float) * particleSpeed;

            const multiply_x_by_1_or_minus_1: f32 = if (rnd.boolean()) 1 else -1;
            const multiply_y_by_1_or_minus_1: f32 = if (rnd.boolean()) 1 else -1;
            vel.x *= multiply_x_by_1_or_minus_1;
            vel.y *= multiply_y_by_1_or_minus_1;
        }

        ast_particles.time_of_creation = rl.getTime();
        ast_particles.lifetime_duration_sec = lifetime_duration_in_sec;
        return ast_particles;
    }

    fn update(self: *AsteroidParticles) bool {
        if (rl.getTime() - self.time_of_creation > self.lifetime_duration_sec) {
            return true;
        }

        for (0..particleCount) |i| {
            self.points[i] = rlm.vector2Add(self.points[i], self.velocities[i]);
        }

        return false;
    }

    fn draw(self: AsteroidParticles) void {
        for (self.points) |point| {
            draw_mod.drawPoint(point);
        }
    }
};
