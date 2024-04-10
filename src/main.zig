const std = @import("std");
const math = std.math;
const rand = std.rand;
const print = std.debug.print;

const rl = @import("raylib");
const rlm = @import("raylib-math");
const Vector2 = rl.Vector2;
const Vector4 = rl.Vector4;
const Matrix  = rl.Matrix;

const Ship = struct {
    const shipPoints: [8]Vector2 = .{
        .{ .x =  0.0, .y =  5.0 },
        .{ .x = -5.0, .y = -5.0 },
        .{ .x =  5.0, .y = -5.0 },
        .{ .x = -3.0, .y = -3.5 },
        .{ .x =  3.0, .y = -3.5 },
        .{ .x = -2.0, .y = -3.5 },
        .{ .x =  2.0, .y = -3.5 },
        .{ .x =  0.0, .y = -7.0 }
    };

    const maxVelocity = 3;

    pos: Vector2,
    vel: Vector2,
    acc: Vector2,
    rot: f32,
    angleWhenEngineLastUsed: f32,
    engineWorking: bool
};

var ship: Ship = undefined;

const Game = struct {
    rightBound: f32,
    leftBound: f32,
    topBound: f32,
    bottomBound: f32,

    winWidthOverGameWidth: f32,
    winHeightOverGameHeight: f32,

    deltaTime: f32
};

var game: Game = undefined;

pub fn init() void {
    game.topBound = 150;
    game.bottomBound = -150;

    const gameWidth =
        (@as(f32, @floatFromInt(rl.getScreenWidth())) / @as(f32, @floatFromInt(rl.getScreenHeight())))
        * (game.topBound + @fabs(game.bottomBound));

    game.leftBound = -gameWidth / 2;
    game.rightBound = gameWidth / 2;

    game.winWidthOverGameWidth = @as(f32, @floatFromInt(rl.getScreenWidth())) / (game.rightBound + @fabs(game.leftBound));
    game.winHeightOverGameHeight = @as(f32, @floatFromInt(rl.getScreenHeight())) / (game.topBound + @fabs(game.bottomBound));

    game.deltaTime = 0;
    
    ship.pos.x = 0;
    ship.pos.y = 0;
    ship.vel.x = 0;
    ship.vel.y = 0;
    ship.acc.x = 0;
    ship.acc.y = 0;
    ship.rot = 0;
    ship.angleWhenEngineLastUsed = 0;
}

pub fn update() void {
    const isAtMaxVel = (math.pow(f32, ship.vel.x, 2) + math.pow(f32, ship.vel.y, 2) 
        >= Ship.maxVelocity * Ship.maxVelocity);

    if (!(isAtMaxVel and
        (math.fabs(ship.vel.x + ship.acc.x * 0.5) > math.fabs(ship.vel.x)
        or math.fabs(ship.vel.y + ship.acc.y * 0.5) > math.fabs(ship.vel.y))))
    {
        ship.vel.x += ship.acc.x * 0.5;
        ship.vel.y += ship.acc.y * 0.5;
    }

    ship.pos.x += ship.vel.x * game.deltaTime * 60;
    ship.pos.y += ship.vel.y * game.deltaTime * 60;
    
    if (!(isAtMaxVel and
        (math.fabs(ship.vel.x + ship.acc.x * 0.5) > math.fabs(ship.vel.x)
        or math.fabs(ship.vel.y + ship.acc.y * 0.5) > math.fabs(ship.vel.y))))
    {
        ship.vel.x += ship.acc.x * 0.5;
        ship.vel.y += ship.acc.y * 0.5;
    }

    if (ship.pos.x < game.leftBound)
        ship.pos.x = game.rightBound;

    if (ship.pos.x > game.rightBound)
        ship.pos.x = game.leftBound;

    if (ship.pos.y < game.bottomBound)
        ship.pos.y = game.topBound;

    if (ship.pos.y > game.topBound)
        ship.pos.y = game.bottomBound;
}

fn input() void {
    rl.pollInputEvents();

    if (rl.isKeyDown(.key_left)) {
        ship.rot -= math.degreesToRadians(f32, 3.0);
    } else if (rl.isKeyDown(.key_right)) {
        ship.rot += math.degreesToRadians(f32, 3.0);
    }
    
    const engineWorkingAcc = 0.1;
    const engineIdleAcc = 0.01;

    const Proportions = struct {
        var xOverTotalVel: f32 = 0;
        var yOverTotalVel: f32 = 0;
    };

    if (rl.isKeyDown(.key_up)) {
        ship.acc.x = -@sin(ship.rot) * engineWorkingAcc;
        ship.acc.y = @cos(ship.rot) * engineWorkingAcc;
        // ship.angleWhenEngineLastUsed = ship.rot;
        ship.angleWhenEngineLastUsed = math.atan(-ship.vel.y / ship.vel.x);

        Proportions.xOverTotalVel = ship.vel.x / @sqrt(ship.vel.x*ship.vel.x + ship.vel.y*ship.vel.y);
        Proportions.yOverTotalVel = ship.vel.y / @sqrt(ship.vel.x*ship.vel.x + ship.vel.y*ship.vel.y);

        ship.engineWorking = true;
    } else {  // If engine is idle
        // Checking if velocity is around 0 because we don't want to make the ship go backwards due to 
        // the deacceleration applied when the engine is idle
        if (ship.vel.x > engineIdleAcc or ship.vel.x < -engineIdleAcc) {
            // ship.acc.x = -@sin(ship.angleWhenEngineLastUsed) * -engineIdleAcc;
            ship.acc.x = -engineIdleAcc * Proportions.xOverTotalVel;
        } else {
            ship.acc.x = 0;
        }
        
        if (ship.vel.y > engineIdleAcc or ship.vel.y < -engineIdleAcc) {
            // ship.acc.y = @cos(ship.angleWhenEngineLastUsed) * -engineIdleAcc;
            ship.acc.y = -engineIdleAcc * Proportions.yOverTotalVel;
        } else {
            ship.acc.y = 0;
        }

        ship.engineWorking = false;
    }
}

fn drawLines() void {
    const FrameCount = struct {
        var frameCount: i32 = 0;
        var drawFire: bool = true;

        pub fn update() void {
            frameCount += 1;

            if (frameCount == 3) {
                frameCount = 0;
                drawFire = !drawFire;
            }
        }
    };

    FrameCount.update();

    const Transform = struct {
        fn rescalePosToWindowDims(pos: Vector2) Vector2 {
            var result: Vector2 = undefined;

            result.x = (pos.x + game.rightBound) * game.winWidthOverGameWidth;
            result.y = (pos.y + game.topBound) * game.winHeightOverGameHeight;

            return result;
        }
    };

    var shipPoints: [8]Vector2 = undefined;
    std.mem.copy(Vector2, &shipPoints, Ship.shipPoints[0..]);

    for (&shipPoints) |*point| {
        point.* = rlm.vector2Add(ship.pos, rlm.vector2Rotate(point.*, ship.rot));
        point.* = Transform.rescalePosToWindowDims(point.*);
    }

    rl.drawLineEx(shipPoints[0], shipPoints[1], 1.0, rl.Color.white);
    rl.drawLineEx(shipPoints[0], shipPoints[2], 1.0, rl.Color.white);
    rl.drawLineEx(shipPoints[1], shipPoints[3], 1.0, rl.Color.white);
    rl.drawLineEx(shipPoints[2], shipPoints[4], 1.0, rl.Color.white);
    rl.drawLineEx(shipPoints[3], shipPoints[4], 1.0, rl.Color.white);

    if (ship.engineWorking and FrameCount.drawFire) {
        rl.drawLineEx(shipPoints[5], shipPoints[7], 1.0, rl.Color.white);
        rl.drawLineEx(shipPoints[6], shipPoints[7], 1.0, rl.Color.white);
    }
}

pub fn main() !void {
    rl.initWindow(rl.getScreenWidth(), rl.getScreenHeight(), "Asteroids");
    defer rl.closeWindow();
    rl.toggleFullscreen();
    rl.setWindowSize(rl.getScreenWidth(), rl.getScreenHeight());

    rl.setTargetFPS(60);

    init();

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        game.deltaTime = rl.getFrameTime();
        // Update
        //----------------------------------------------------------------------------------
        input();
        update();

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        
        drawLines();
    }
}
