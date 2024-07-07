const std = @import("std");
const math = std.math;
const rand = std.rand;

const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;
const Matrix  = rl.Matrix;

const Game = struct {
    rightBound: f32,
    leftBound: f32,
    bottomBound: f32,
    topBound: f32,

    winWidthOverGameWidth: f32,
    winHeightOverGameHeight: f32,

    deltaTime: f32,

    fn init(self: *Game) void {
        self.bottomBound = 150;
        self.topBound = -150;

        const gameWidth =
            (@as(f32, @floatFromInt(rl.getScreenWidth()))
             / @as(f32, @floatFromInt(rl.getScreenHeight())))
            * (self.bottomBound + @abs(self.topBound));

        self.leftBound = -gameWidth / 2;
        self.rightBound = gameWidth / 2;

        self.winWidthOverGameWidth =
            @as(f32, @floatFromInt(rl.getScreenWidth()))
            / (self.rightBound + @abs(self.leftBound));

        self.winHeightOverGameHeight =
            @as(f32, @floatFromInt(rl.getScreenHeight()))
            / (self.bottomBound + @abs(self.topBound));

        self.deltaTime = 0;
    }

    /// Normalizes delta time so when the fps is 60, the return value is 1
    fn deltaTimeNormalized(self: @This()) f32 {
        return self.deltaTime * 60;
    }
};

var game: Game = undefined;

const Ship = struct {
    const Line = struct {
        pointA: Vector2,
        pointB: Vector2
    };

    const defaultShipLines: [7]Line = .{
        .{ .pointA = .{ .x =  0.0, .y =  5.0 }, .pointB = .{ .x = -5.0, .y = -5.0 } },
        .{ .pointA = .{ .x =  0.0, .y =  5.0 }, .pointB = .{ .x =  5.0, .y = -5.0 } },
        .{ .pointA = .{ .x = -5.0, .y = -5.0 }, .pointB = .{ .x = -3.0, .y = -3.5 } },
        .{ .pointA = .{ .x =  5.0, .y = -5.0 }, .pointB = .{ .x =  3.0, .y = -3.5 } },
        .{ .pointA = .{ .x = -3.0, .y = -3.5 }, .pointB = .{ .x =  3.0, .y = -3.5 } },
        .{ .pointA = .{ .x = -2.0, .y = -3.5 }, .pointB = .{ .x =  0.0, .y = -7.0 } },
        .{ .pointA = .{ .x =  2.0, .y = -3.5 }, .pointB = .{ .x =  0.0, .y = -7.0 } }
    };

    const maxVelocity = 5;
    const engineWorkingAcc = 0.1;
    const engineIdleAcc = 0.02;
    const rotationSpeed = 3.0;

    const ShipLinesRandVelocities = struct {
        var velocities: [7]Vector2 = undefined;

        fn setRandVelocities() void {
            for (&velocities) |*value| {
                value.x = (Asteroid.rnd.random().float(f32) - 0.5);
                value.y = (Asteroid.rnd.random().float(f32) - 0.5);
            }
        }
    };

    fn init(self: *Ship) void {
        std.mem.copyForwards(Line, &self.shipLines, &defaultShipLines);
        self.pos.x = 0;
        self.pos.y = 0;
        self.vel.x = 0;
        self.vel.y = 0;
        self.acc.x = 0;
        self.acc.y = 0;
        self.rot = 0;
        self.angleWhenEngineLastUsed = 0;
        self.engineWorking = false;
        self.collided = false;
    }

    fn hasCollided(self: *Ship) void {
        if (self.collided) {
            return;
        }

        self.collided = true;
        self.acc = .{ .x = 0, .y = 0 };
        // self.vel = .{ .x = 0, .y = 0 };
        self.engineWorking = false;
        ShipLinesRandVelocities.setRandVelocities();
    }

    fn rotateLeftwards(self: *Ship) void {
        self.rot -= math.degreesToRadians(rotationSpeed) * game.deltaTimeNormalized();
    }

    fn rotateRightwards(self: *Ship) void {
        self.rot += math.degreesToRadians(rotationSpeed) * game.deltaTimeNormalized();
    }

    fn update(self: *Ship) void {
        if (self.collided) {
            for (&self.shipLines, 0..) |*line, i| {
                line.pointA = rlm.vector2Add(
                    line.pointA,
                    rlm.vector2Scale(ShipLinesRandVelocities.velocities[i], game.deltaTimeNormalized())
                ); 
                line.pointB = rlm.vector2Add(
                    line.pointB,
                    rlm.vector2Scale(ShipLinesRandVelocities.velocities[i], game.deltaTimeNormalized())
                ); 
            }
        } else if (self.engineWorking) {
            ship.acc.x = -@sin(ship.rot) * engineWorkingAcc;
            ship.acc.y = @cos(ship.rot) * engineWorkingAcc;
        } else {
            if (ship.vel.x > engineIdleAcc or ship.vel.x < -engineIdleAcc) {
                ship.acc.x = -engineIdleAcc * @cos(ship.angleWhenEngineLastUsed);
            } else {
                ship.acc.x = 0;
            }

            if (ship.vel.y > engineIdleAcc or ship.vel.y < -engineIdleAcc) {
                ship.acc.y = -engineIdleAcc * @sin(ship.angleWhenEngineLastUsed);
            } else {
                ship.acc.y = 0;
            }
        }

        const isAtMaxVel =
            (math.pow(f32, self.vel.x, 2) + math.pow(f32, self.vel.y, 2)
            >= Ship.maxVelocity * Ship.maxVelocity);

        const applyAccelerationCondition = !(isAtMaxVel and
            (@abs(self.vel.x + self.acc.x * 0.5) > @abs(self.vel.x)
            or @abs(self.vel.y + self.acc.y * 0.5) > @abs(self.vel.y)));

        if (applyAccelerationCondition) {
            self.vel.x += self.acc.x * 0.5 * game.deltaTimeNormalized();
            self.vel.y += self.acc.y * 0.5 * game.deltaTimeNormalized();
        }

        self.pos.x += self.vel.x * game.deltaTimeNormalized();
        self.pos.y += self.vel.y * game.deltaTimeNormalized();

        if (applyAccelerationCondition) {
            self.vel.x += self.acc.x * 0.5 * game.deltaTimeNormalized();
            self.vel.y += self.acc.y * 0.5 * game.deltaTimeNormalized();
        }

        if (self.pos.x < game.leftBound) {  
            self.pos.x = game.rightBound;
        }

        if (self.pos.x > game.rightBound) {  
            self.pos.x = game.leftBound;
        }

        if (self.pos.y < game.topBound) {  
            self.pos.y = game.bottomBound;
        }

        if (self.pos.y > game.bottomBound) {  
            self.pos.y = game.topBound;
        }
    }

    fn draw(self: *Ship) void {
        const FrameCount = struct {
            var frameCount: i32 = 0;
            var drawFire: bool = true;

            fn update() void {
                frameCount += 1;

                if (frameCount == 3) {
                    frameCount = 0;
                    drawFire = !drawFire;
                }
            }
        };

        FrameCount.update();

        var shipLines: [7]Line = undefined;
        std.mem.copyForwards(Line, &shipLines, self.shipLines[0..]);

        for (&shipLines) |*line| {
            line.pointA = rlm.vector2Add(ship.pos, rlm.vector2Rotate(line.pointA, ship.rot));
            line.pointB = rlm.vector2Add(ship.pos, rlm.vector2Rotate(line.pointB, ship.rot));
            line.pointA = convertFromGameToWindowCoords(line.pointA);
            line.pointB = convertFromGameToWindowCoords(line.pointB);
        }

        const thickness = 1.0;

        for (shipLines[0..5]) |line| {
            rl.drawLineEx(line.pointA, line.pointB, thickness, rl.Color.white);
        }

        if (ship.engineWorking and FrameCount.drawFire) {
            rl.drawLineEx(shipLines[5].pointA, shipLines[5].pointB, thickness, rl.Color.white);
            rl.drawLineEx(shipLines[6].pointA, shipLines[6].pointB, thickness, rl.Color.white);
        }
    }

    shipLines: [7]Line,
    pos: Vector2,
    vel: Vector2,
    acc: Vector2,
    rot: f32,
    angleWhenEngineLastUsed: f32,
    engineWorking: bool,
    collided: bool,
};

var ship: Ship = undefined;

const Asteroid = struct {
    const Size = enum {
        small,
        medium,
        large
    };

    const SpawnSide = enum {
        top,
        bottom,
        left,
        right
    };

    fn radius(size: Size) f32 {
        return switch (size) {
            .small => 4,
            .medium => 8,
            .large => 12
        };
    }

    // Needed to multiply random values in new() function since the random values are too small
    fn randomMultiplier(size: Size) f32 {
        return switch (size) {
            .small => 1.8,
            .medium => 3.6,
            .large => 5.8
        };
    }

    fn speedMultiplier(size: Size) f32 {
        return switch (size) {
            .small => 1.5,
            .medium => 1.0,
            .large => 0.8
        };
    }

    fn pointsOnCircle(size: Size) *const [8]Vector2 {
        return switch (size) {
            .small => &pointsOnCircleSmallAst,
            .medium => &pointsOnCircleMediumAst,
            .large => &pointsOnCircleLargeAst
        };
    }

    var pointsOnCircleSmallAst: [8]Vector2 = undefined;
    var pointsOnCircleMediumAst: [8]Vector2 = undefined;
    var pointsOnCircleLargeAst: [8]Vector2 = undefined;

    fn initStruct() void {
        rnd = rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));

        for (0..8) |i| {
            pointsOnCircleSmallAst[i] =
                .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.small),
                   .y = @sin(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.small) };
            pointsOnCircleMediumAst[i] =
                .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.medium),
                   .y = @sin(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.medium) };
            pointsOnCircleLargeAst[i] =
                .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.large),
                   .y = @sin(math.degreesToRadians(360.0 / 8.0 * @as(f32, @floatFromInt(i)))) * radius(.large) };
        }
    }

    fn new() Asteroid {
        var astr: Asteroid = .{
            .points = undefined,
            .pos = undefined,
            .velocity = undefined,
            .size = undefined,
            .spawnSide = undefined
        };

        const rand_int = @mod(rnd.random().int(i32), 100);

        if (rand_int >= 90) {
            astr.size = .large;
        } else if (rand_int >= 20) {
            astr.size = .medium;
        } else {
            astr.size = .small;
        }

        astr.spawnSide = @enumFromInt(@mod(rnd.random().int(i32), 4));

        if (astr.spawnSide == .top) {
            astr.pos.x = (rnd.random().float(f32) - 0.5) * (game.rightBound + @abs(game.leftBound));
            astr.pos.y = game.topBound - radius(astr.size);
            astr.velocity.x = (rnd.random().float(f32) - 0.5) * 2;
            astr.velocity.y = (1 - astr.velocity.x);
        } else if (astr.spawnSide == .bottom) {
            astr.pos.x = (rnd.random().float(f32) - 0.5) * (game.rightBound + @abs(game.leftBound));
            astr.pos.y = game.bottomBound + radius(astr.size);
            astr.velocity.x = (rnd.random().float(f32) - 0.5) * 2;
            astr.velocity.y = (1 - astr.velocity.x) * (-1);
        } else if (astr.spawnSide == .left) {
            astr.pos.x = game.leftBound - radius(astr.size);
            astr.pos.y = (rnd.random().float(f32) - 0.5) * (game.bottomBound + @abs(game.topBound));
            astr.velocity.x = rnd.random().float(f32);
            astr.velocity.y = (1 - astr.velocity.x);
        } else if (astr.spawnSide == .right) {
            astr.pos.x = game.rightBound + radius(astr.size);
            astr.pos.y = (rnd.random().float(f32) - 0.5) * (game.bottomBound + @abs(game.topBound));
            astr.velocity.x = rnd.random().float(f32) * (-1);
            astr.velocity.y = (1 - astr.velocity.x) * (-1);
        }

        astr.velocity.x *= speedMultiplier(astr.size);
        astr.velocity.y *= speedMultiplier(astr.size);

        for (astr.points, 0..) |_, i| {
            // The random number is always positive, and I don't want
            // coordinates to only increase since it would be weird when
            // checking for collision as center wouldn't really be in center
            const multiplyXby1orMinus1: f32 =
                if (rnd.random().boolean()) -1 else 1;

            const multiplyYby1orMinus1: f32 =
                if (rnd.random().boolean()) -1 else 1;

            astr.points[i].x =
                Asteroid.pointsOnCircle(astr.size)[i].x
                + multiplyXby1orMinus1 * rnd.random().float(f32)
                * randomMultiplier(astr.size);

            astr.points[i].y =
                Asteroid.pointsOnCircle(astr.size)[i].y
                + multiplyYby1orMinus1 * rnd.random().float(f32)
                * randomMultiplier(astr.size);
        }

        return astr;
    }

    fn checkIfOutOfBounds(self: *Asteroid, top: bool, bottom: bool, left: bool, right: bool) bool {
        if (top and self.pos.y < game.topBound) {
            return true;
        }

        if (bottom and self.pos.y > game.bottomBound) {
            return true;
        }

        if (left and self.pos.x < game.leftBound) {
            return true;
        }

        if (right and self.pos.x > game.rightBound) {
            return true;
        }

        return false;
    }

    fn update(self: *Asteroid) void {
        self.pos.x += self.velocity.x * game.deltaTimeNormalized();
        self.pos.y += self.velocity.y * game.deltaTimeNormalized();

        if ((self.spawnSide == .top and checkIfOutOfBounds(self, false, true, true, true)) or
            (self.spawnSide == .bottom and checkIfOutOfBounds(self, true, false, true, true)) or
            (self.spawnSide == .left and checkIfOutOfBounds(self, true, true, false, true)) or
            (self.spawnSide == .right and checkIfOutOfBounds(self, true, true, true, false)))
        {
            self.* = new();
        }

        if (rl.math.vector2Distance(self.pos, ship.pos) <= radius(self.size)) {
            ship.hasCollided();
        }
    }

    var rnd: rand.Xoshiro256 = undefined;

    points: [8]Vector2,
    pos: Vector2,
    velocity: Vector2,
    size: Size,
    spawnSide: SpawnSide,
};

const numAsteroids = 30;
var asteroids: [numAsteroids]Asteroid = undefined;

fn init() void {
    game.init();
    ship.init();

    for (asteroids[0..]) |*astr| {
        astr.* = Asteroid.new();
    }
}

fn update() void {
    ship.update();

    for (asteroids[0..]) |*astr| {
        astr.update();
    }
}

fn input() void {
    if (ship.collided) {
        if (rl.isKeyDown(.key_space)) {
            ship.init();
        }

        return;
    }

    if (rl.isKeyDown(.key_left)) {
        ship.rotateLeftwards();
    } else if (rl.isKeyDown(.key_right)) {
        ship.rotateRightwards();
    }

    if (rl.isKeyDown(.key_up)) {
        ship.engineWorking = true;
    } else if (rl.isKeyReleased(.key_up)) {
        ship.angleWhenEngineLastUsed = math.atan2(ship.vel.y, ship.vel.x);
        ship.engineWorking = false;
    } else {
        ship.engineWorking = false;
    }
}

fn convertFromGameToWindowCoords(vec: Vector2) Vector2 {
    var result: Vector2 = undefined;
    result.x = (vec.x + game.rightBound) * game.winWidthOverGameWidth;
    result.y = (vec.y + game.bottomBound) * game.winHeightOverGameHeight;
    return result;
}

fn drawAsteroids() void {
    for (asteroids) |astr| {
        for (0..astr.points.len - 1) |i| {
            rl.drawLineEx(
                convertFromGameToWindowCoords(rlm.vector2Add(astr.points[i], astr.pos)),
                convertFromGameToWindowCoords(rlm.vector2Add(astr.points[i+1], astr.pos)),
                1.0,
                rl.Color.white
            );
        }

        rl.drawLineEx(
            convertFromGameToWindowCoords(rlm.vector2Add(astr.points[0], astr.pos)),
            convertFromGameToWindowCoords(rlm.vector2Add(astr.points[astr.points.len - 1], astr.pos)),
            1.0,
            rl.Color.white
        );
    }
}

pub fn main() !void {
    rl.setConfigFlags(.{ .vsync_hint = true });

    // const width = 1280;
    // const height = 960;
    // rl.initWindow(width, height, "Asteroids");
    // defer rl.closeWindow();
    // rl.setWindowSize(width, height);

    rl.initWindow(rl.getScreenWidth(), rl.getScreenHeight(), "Asteroids");
    defer rl.closeWindow();
    rl.toggleFullscreen();
    rl.setWindowSize(rl.getScreenWidth(), rl.getScreenHeight());

    rl.setTargetFPS(60);

    Asteroid.initStruct();
    init();

    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        game.deltaTime = rl.getFrameTime();
        // Update
        //---------------------------------------------------------------------
        input();
        update();

        // Draw
        //---------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        ship.draw();
        drawAsteroids();
    }
}
