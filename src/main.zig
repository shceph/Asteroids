const std = @import("std");
const math = std.math;
const rand = std.rand;
const print = std.debug.print;

const rl = @import("raylib");
const rlm = @import("raylib-math");
const Vector2 = rl.Vector2;

const Ship = struct {
    const shipPoints: [5]Vector2 = .{
        .{ .x =  0.0, .y =  5.0 },
        .{ .x = -5.0, .y = -5.0 },
        .{ .x =  5.0, .y = -5.0 },
        .{ .x = -3.0, .y = -3.5 },
        .{ .x =  3.0, .y = -3.5 }
    };

    const maxVelocity = 3;

    pub fn update(self: *@This()) void {
        // if (self.*.acc.x < 0 and self.*.vel.x < 0.02 and self.*.vel.x > -0.02)
        //     self.*.vel.x = 0.0;

        // if (self.*.acc.y < 0 and self.*.vel.y < 0.02 and self.*.vel.y > -0.02)
            // self.*.vel.y = 0.0;
        
        const isAtMaxVel = (math.pow(f32, self.*.vel.x, 2) + math.pow(f32, self.*.vel.y, 2) >= maxVelocity);

        if (!(isAtMaxVel 
            and math.fabs(self.*.vel.x + self.*.acc.x * 0.5) > math.fabs(self.*.vel.x)
            and math.fabs(self.*.vel.y + self.*.acc.y * 0.5) > math.fabs(self.*.vel.y)))
        {
            self.*.vel.x += self.*.acc.x * 0.5;
            self.*.vel.y += self.*.acc.y * 0.5;
        }

        self.*.pos.x += self.*.vel.x;
        self.*.pos.y += self.*.vel.y;
        
        if (!(isAtMaxVel 
            and math.fabs(self.*.vel.x + self.*.acc.x * 0.5) > math.fabs(self.*.vel.x)
            and math.fabs(self.*.vel.y + self.*.acc.y * 0.5) > math.fabs(self.*.vel.y)))
        {
            self.*.vel.x += self.*.acc.x * 0.5;
            self.*.vel.y += self.*.acc.y * 0.5;
        }

        if (self.*.pos.x < 0)
            self.*.pos.x = Game.windowWidth;

        if (self.*.pos.x > Game.windowWidth)
            self.*.pos.x = 0;

        if (self.*.pos.y < 0)
            self.*.pos.y = Game.windowHeight;

        if (self.*.pos.x > Game.windowHeight)
            self.*.pos.x = 0;
    }

    pos: Vector2,
    vel: Vector2,
    acc: Vector2,
    rot: f32,
};

var ship: Ship = undefined;

const Game = struct {
    const scale = 4;

    const windowWidth = 1280;
    const windowHeight = 1024;

    pub fn init() void {
        ship.pos.x = windowWidth / 2 / Game.scale;
        ship.pos.y = windowHeight / 2 / Game.scale;
        ship.vel.x = 0.0;
        ship.vel.y = 0.0;
        ship.acc.x = 0.0;
        ship.acc.y = 0.0;
        ship.rot = 0.0;
    }
};

var game: Game = undefined;

fn input() void {
    rl.pollInputEvents();

    if (rl.isKeyDown(rl.KeyboardKey.key_left)) {
        // ship.pos.x -= 1;
        ship.rot -= math.degreesToRadians(f32, 3.0);
    } else if (rl.isKeyDown(rl.KeyboardKey.key_right)) {
        // ship.pos.x += 1;
        ship.rot += math.degreesToRadians(f32, 3.0);
    }

    if (rl.isKeyDown(rl.KeyboardKey.key_up)) {
        ship.acc.x = -@sin(ship.rot) * 0.1;
        ship.acc.y = @cos(ship.rot) * 0.1;
    } else {
        // ship.acc.x = -@cos(ship.rot) * -0.01;
        // ship.acc.y = @sin(ship.rot) * -0.01;
    }
}

fn drawLines() void {
    var shipPoints: [5]Vector2 = undefined;
    std.mem.copy(Vector2, &shipPoints, Ship.shipPoints[0..]);

    for (&shipPoints) |*point| {
        point.* = rlm.vector2Add(ship.pos, rlm.vector2Rotate(point.*, ship.rot));
        point.* = rlm.vector2Scale(point.*, Game.scale);
        // point.*.x *= Game.scale;
        // point.*.y *= Game.scale;
    }

    rl.drawLineEx(shipPoints[0], shipPoints[1], 1.0, rl.Color.white);
    rl.drawLineEx(shipPoints[0], shipPoints[2], 1.0, rl.Color.white);
    rl.drawLineEx(shipPoints[1], shipPoints[3], 1.0, rl.Color.white);
    rl.drawLineEx(shipPoints[2], shipPoints[4], 1.0, rl.Color.white);
    rl.drawLineEx(shipPoints[3], shipPoints[4], 1.0, rl.Color.white);
}

pub fn main() !void {
    Game.init();

    rl.initWindow(Game.windowWidth, Game.windowHeight, "Asteroids");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------
        input();
        ship.update();

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        
        drawLines();
    }
}
