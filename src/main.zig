const std = @import("std");
const math = std.math;
const rand = std.rand;
const print = std.debug.print;

const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;
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

    const maxVelocity = 5;
    const engineWorkingAcc = 0.1;
    const engineIdleAcc = 0.02;
    const rotationSpeed = 3.0;

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
    bottomBound: f32,
    topBound: f32,

    winWidthOverGameWidth: f32,
    winHeightOverGameHeight: f32,

    deltaTime: f32,

    /// Normalizes delta time so when the fps is 60, the return value is 1
    fn deltaTimeNormalized(self: @This()) f32 {
        return self.deltaTime * 60;
    }
};

var game: Game = undefined;

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

    pub fn radius(size: Size) f32 {
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
            .small => 2.0,
            .medium => 1.5,
            .large => 1.0
        };
    }

    pub fn pointsOnCircle(size: Size) *const [8]Vector2 {
        return switch (size) {
            .small => &pointsOnCircleSmallAst,
            .medium => &pointsOnCircleMediumAst,
            .large => &pointsOnCircleLargeAst
        };
    }

    pub fn initStruct() void {
        rnd = rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
    }

    pub fn new() Asteroid {
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
            astr.velocity.y = rnd.random().float(f32);
        } else if (astr.spawnSide == .bottom) {
            astr.pos.x = (rnd.random().float(f32) - 0.5) * (game.bottomBound + @abs(game.topBound));
            astr.pos.y = game.bottomBound + radius(astr.size);
            astr.velocity.x = (rnd.random().float(f32) - 0.5) * 2;
            astr.velocity.y = rnd.random().float(f32) * (-1);
        } else if (astr.spawnSide == .left) {
            astr.pos.x = game.leftBound - radius(astr.size);
            astr.pos.y = (rnd.random().float(f32) - 0.5) * (game.topBound + @abs(game.bottomBound));
            astr.velocity.x = rnd.random().float(f32);
            astr.velocity.y = (rnd.random().float(f32) - 0.5) * 2;
        } else if (astr.spawnSide == .right) {
            astr.pos.x = game.rightBound + radius(astr.size);
            astr.pos.y = (rnd.random().float(f32) - 0.5) * (game.rightBound + @abs(game.leftBound));
            astr.velocity.x = rnd.random().float(f32) * (-1);
            astr.velocity.y = (rnd.random().float(f32) - 0.5) * 2;
        }

        astr.velocity.x += 0.3;
        astr.velocity.y += 0.3;
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

    fn checkIfOutOfBounds(self: *@This(), top: bool, bottom: bool, left: bool, right: bool) bool {
        if (top and self.*.pos.y < game.topBound) {
            return true;
        }

        if (bottom and self.*.pos.y > game.bottomBound) {
            return true;
        }

        if (left and self.*.pos.x < game.leftBound) {
            return true;
        }

        if (right and self.*.pos.x > game.rightBound) {
            return true;
        }

        return false;
    }

    fn update(self: *@This()) void {
        self.*.pos.x += self.velocity.x * game.deltaTimeNormalized();
        self.*.pos.y += self.velocity.y * game.deltaTimeNormalized();

        if ((self.*.spawnSide == .top and checkIfOutOfBounds(self, false, true, true, true)) or
            (self.*.spawnSide == .bottom and checkIfOutOfBounds(self, true, false, true, true)) or
            (self.*.spawnSide == .left and checkIfOutOfBounds(self, true, true, false, true)) or
            (self.*.spawnSide == .right and checkIfOutOfBounds(self, true, true, true, false)))
        {
            self.* = new();
        }
    }

    // Asteroid shape is generated by adding radnom values to the already known coordinates of points
    // on a circle
    const pointsOnCircleSmallAst: [8]Vector2 = .{
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 0)) * radius(.small),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 0)) * radius(.small) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 1)) * radius(.small),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 1)) * radius(.small) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 2)) * radius(.small),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 2)) * radius(.small) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 3)) * radius(.small),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 3)) * radius(.small) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 4)) * radius(.small),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 4)) * radius(.small) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 5)) * radius(.small),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 5)) * radius(.small) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 6)) * radius(.small),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 6)) * radius(.small) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 7)) * radius(.small),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 7)) * radius(.small) }
    };

    const pointsOnCircleMediumAst: [8]Vector2 = .{
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 0)) * radius(.medium),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 0)) * radius(.medium) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 1)) * radius(.medium),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 1)) * radius(.medium) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 2)) * radius(.medium),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 2)) * radius(.medium) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 3)) * radius(.medium),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 3)) * radius(.medium) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 4)) * radius(.medium),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 4)) * radius(.medium) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 5)) * radius(.medium),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 5)) * radius(.medium) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 6)) * radius(.medium),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 6)) * radius(.medium) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 7)) * radius(.medium),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 7)) * radius(.medium) }
    };

    const pointsOnCircleLargeAst: [8]Vector2 = .{
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 0)) * radius(.large),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 0)) * radius(.large) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 1)) * radius(.large),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 1)) * radius(.large) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 2)) * radius(.large),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 2)) * radius(.large) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 3)) * radius(.large),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 3)) * radius(.large) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 4)) * radius(.large),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 4)) * radius(.large) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 5)) * radius(.large),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 5)) * radius(.large) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 6)) * radius(.large),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 6)) * radius(.large) },
        .{ .x = @cos(math.degreesToRadians(360.0 / 8.0 * 7)) * radius(.large),
           .y = @sin(math.degreesToRadians(360.0 / 8.0 * 7)) * radius(.large) }
    };

    var rnd: rand.Xoshiro256 = undefined;

    points: [8]Vector2,
    pos: Vector2,
    velocity: Vector2,
    size: Size,
    spawnSide: SpawnSide,
};

const numAsteroids = 10;
var asteroids: [numAsteroids]Asteroid = undefined;

pub fn init() void {
    game.bottomBound = 150;
    game.topBound = -150;

    const gameWidth =
        (@as(f32, @floatFromInt(rl.getScreenWidth()))
         / @as(f32, @floatFromInt(rl.getScreenHeight())))
        * (game.bottomBound + @abs(game.topBound));

    game.leftBound = -gameWidth / 2;
    game.rightBound = gameWidth / 2;

    game.winWidthOverGameWidth =
        @as(f32, @floatFromInt(rl.getScreenWidth()))
        / (game.rightBound + @abs(game.leftBound));

    game.winHeightOverGameHeight =
        @as(f32, @floatFromInt(rl.getScreenHeight()))
        / (game.bottomBound + @abs(game.topBound));

    game.deltaTime = 0;

    ship.pos.x = 0;
    ship.pos.y = 0;
    ship.vel.x = 0;
    ship.vel.y = 0;
    ship.acc.x = 0;
    ship.acc.y = 0;
    ship.rot = 0;
    ship.angleWhenEngineLastUsed = 0;

    for (asteroids[0..]) |*astr| {
        astr.* = Asteroid.new();
    }
}

pub fn update() void {
    const isAtMaxVel =
        (math.pow(f32, ship.vel.x, 2) + math.pow(f32, ship.vel.y, 2)
        >= Ship.maxVelocity * Ship.maxVelocity);

    if (!(isAtMaxVel and
        (@abs(ship.vel.x + ship.acc.x * 0.5) > @abs(ship.vel.x)
        or @abs(ship.vel.y + ship.acc.y * 0.5) > @abs(ship.vel.y))))
    {
        ship.vel.x += ship.acc.x * 0.5 * game.deltaTimeNormalized();
        ship.vel.y += ship.acc.y * 0.5 * game.deltaTimeNormalized();
    }

    ship.pos.x += ship.vel.x * game.deltaTimeNormalized();
    ship.pos.y += ship.vel.y * game.deltaTimeNormalized();

    if (!(isAtMaxVel and
        (@abs(ship.vel.x + ship.acc.x * 0.5) > @abs(ship.vel.x)
        or @abs(ship.vel.y + ship.acc.y * 0.5) > @abs(ship.vel.y))))
    {
        ship.vel.x += ship.acc.x * 0.5 * game.deltaTimeNormalized();
        ship.vel.y += ship.acc.y * 0.5 * game.deltaTimeNormalized();
    }

    if (ship.pos.x < game.leftBound)
        ship.pos.x = game.rightBound;

    if (ship.pos.x > game.rightBound)
        ship.pos.x = game.leftBound;

    if (ship.pos.y < game.topBound)
        ship.pos.y = game.bottomBound;

    if (ship.pos.y > game.bottomBound)
        ship.pos.y = game.topBound;

    for (asteroids[0..]) |*astr| {
        astr.*.update();
    }
}

fn input() void {
    rl.pollInputEvents();

    if (rl.isKeyDown(.key_left)) {
        ship.rot -= math.degreesToRadians(Ship.rotationSpeed);
    } else if (rl.isKeyDown(.key_right)) {
        ship.rot += math.degreesToRadians(Ship.rotationSpeed);
    }

    const Proportions = struct {
        var xOverTotalVel: f32 = 0;
        var yOverTotalVel: f32 = 0;
    };

    if (rl.isKeyDown(.key_up)) {
        ship.acc.x = -@sin(ship.rot) * Ship.engineWorkingAcc;
        ship.acc.y = @cos(ship.rot) * Ship.engineWorkingAcc;
        // ship.angleWhenEngineLastUsed = ship.rot;
        ship.angleWhenEngineLastUsed = math.atan(-ship.vel.y / ship.vel.x);

        Proportions.xOverTotalVel =
            ship.vel.x / @sqrt(ship.vel.x*ship.vel.x + ship.vel.y*ship.vel.y);
        Proportions.yOverTotalVel =
            ship.vel.y / @sqrt(ship.vel.x*ship.vel.x + ship.vel.y*ship.vel.y);

        ship.engineWorking = true;
    } else {  // If engine is idle
        // Checking if velocity is around 0 because we don't want to make the ship go backwards due to
        // the deacceleration applied when the engine is idle
        if (ship.vel.x > Ship.engineIdleAcc or ship.vel.x < -Ship.engineIdleAcc) {
            ship.acc.x = -Ship.engineIdleAcc * Proportions.xOverTotalVel;
        } else {
            ship.acc.x = 0;
        }

        if (ship.vel.y > Ship.engineIdleAcc or ship.vel.y < -Ship.engineIdleAcc) {
            ship.acc.y = -Ship.engineIdleAcc * Proportions.yOverTotalVel;
        } else {
            ship.acc.y = 0;
        }

        ship.engineWorking = false;
    }
}

fn rescaleVec2ToWindowDims(vec: Vector2) Vector2 {
    var result: Vector2 = undefined;
    result.x = (vec.x + game.rightBound) * game.winWidthOverGameWidth;
    result.y = (vec.y + game.bottomBound) * game.winHeightOverGameHeight;
    return result;
}

fn drawShip() void {
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

    var shipPoints: [8]Vector2 = undefined;
    std.mem.copyForwards(Vector2, &shipPoints, Ship.shipPoints[0..]);

    for (&shipPoints) |*point| {
        point.* = rlm.vector2Add(ship.pos, rlm.vector2Rotate(point.*, ship.rot));
        point.* = rescaleVec2ToWindowDims(point.*);
    }

    const thickness = 1.0;

    rl.drawLineEx(shipPoints[0], shipPoints[1], thickness, rl.Color.white);
    rl.drawLineEx(shipPoints[0], shipPoints[2], thickness, rl.Color.white);
    rl.drawLineEx(shipPoints[1], shipPoints[3], thickness, rl.Color.white);
    rl.drawLineEx(shipPoints[2], shipPoints[4], thickness, rl.Color.white);
    rl.drawLineEx(shipPoints[3], shipPoints[4], thickness, rl.Color.white);

    if (ship.engineWorking and FrameCount.drawFire) {
        rl.drawLineEx(shipPoints[5], shipPoints[7], thickness, rl.Color.white);
        rl.drawLineEx(shipPoints[6], shipPoints[7], thickness, rl.Color.white);
    }
}

fn drawAsteroids() void {
    for (asteroids) |astr| {
        for (0..astr.points.len - 1) |i| {
            rl.drawLineEx(
                rescaleVec2ToWindowDims(rlm.vector2Add(astr.points[i], astr.pos)),
                rescaleVec2ToWindowDims(rlm.vector2Add(astr.points[i+1], astr.pos)),
                1.0,
                rl.Color.white
            );
        }

        rl.drawLineEx(
            rescaleVec2ToWindowDims(rlm.vector2Add(astr.points[0], astr.pos)),
            rescaleVec2ToWindowDims(rlm.vector2Add(astr.points[astr.points.len - 1], astr.pos)),
            1.0,
            rl.Color.white
        );
    }
}

pub fn main() !void {
    rl.setConfigFlags(.{ .vsync_hint = true });
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
        drawShip();
        drawAsteroids();
    }
}
