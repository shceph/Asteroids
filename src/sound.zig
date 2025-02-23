const rl = @import("raylib");

pub const sounds = struct {
    pub var ship_shooting: rl.Sound = undefined;
    pub var ship_destroyed: rl.Sound = undefined;
    pub var alien_shooting: rl.Sound = undefined;
    pub var asteroid_explosion: rl.Sound = undefined;

    pub fn initSounds() !void {
        ship_shooting = try rl.loadSound("assets/ship_shooting.mp3");
        ship_destroyed = try rl.loadSound("assets/ship_destroyed.mp3");
        alien_shooting = try rl.loadSound("assets/alien_shooting.mp3");
        asteroid_explosion = try rl.loadSound("assets/asteroid_explosion.mp3");
    }
};
