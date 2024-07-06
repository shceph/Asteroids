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
    // rl.drawLineEx(shipPoints[0], shipPoints[1], thickness, rl.Color.white);
    // rl.drawLineEx(shipPoints[0], shipPoints[2], thickness, rl.Color.white);
    // rl.drawLineEx(shipPoints[1], shipPoints[3], thickness, rl.Color.white);
    // rl.drawLineEx(shipPoints[2], shipPoints[4], thickness, rl.Color.white);
    // rl.drawLineEx(shipPoints[3], shipPoints[4], thickness, rl.Color.white);

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

        pub fn setRandVelocities() void {
            for (&velocities) |*value| {
                value.x = (Asteroid.rnd.random().float(f32) - 0.5) * 2;
                value.y = (Asteroid.rnd.random().float(f32) - 0.5) * 2;
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
        self.vel = .{ .x = 0, .y = 0 };
        self.engineWorking = false;
        ShipLinesRandVelocities.setRandVelocities();
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

        if (self.pos.x < game.leftBound)
            self.pos.x = game.rightBound;

        if (self.pos.x > game.rightBound)
            self.pos.x = game.leftBound;

        if (self.pos.y < game.topBound)
            self.pos.y = game.bottomBound;

        if (self.pos.y > game.bottomBound)
            self.pos.y = game.topBound;
    }

    fn draw(self: *Ship) void {
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

        var shipLines: [7]Line = undefined;
        std.mem.copyForwards(Line, &shipLines, self.shipLines[0..]);

        for (&shipLines) |*line| {
            line.pointA = rlm.vector2Add(ship.pos, rlm.vector2Rotate(line.pointA, ship.rot));
            line.pointB = rlm.vector2Add(ship.pos, rlm.vector2Rotate(line.pointB, ship.rot));
            line.pointA = rescaleVec2ToWindowDims(line.pointA);
            line.pointB = rescaleVec2ToWindowDims(line.pointB);
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
    collided: bool
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
            .small => 1.5,
            .medium => 1.0,
            .large => 0.8
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

const numAsteroids = 30;
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

    ship.init();

    for (asteroids[0..]) |*astr| {
        astr.* = Asteroid.new();
    }
}

pub fn update() void {
    ship.update();

    for (asteroids[0..]) |*astr| {
        astr.update();
    }
}

fn input() void {
    rl.pollInputEvents();

    if (ship.collided) {
        if (rl.isKeyDown(.key_space)) {
            ship.init();
        }

        return;
    }

    if (rl.isKeyDown(.key_left)) {
        ship.rot -= math.degreesToRadians(Ship.rotationSpeed) * game.deltaTimeNormalized();
    } else if (rl.isKeyDown(.key_right)) {
        ship.rot += math.degreesToRadians(Ship.rotationSpeed) * game.deltaTimeNormalized();
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

    const width = 1280;
    const height = 960;
    rl.initWindow(width, height, "Asteroids");
    defer rl.closeWindow();
    rl.setWindowSize(width, height);

    // rl.initWindow(rl.getScreenWidth(), rl.getScreenHeight(), "Asteroids");
    // defer rl.closeWindow();
    // rl.toggleFullscreen();
    // rl.setWindowSize(rl.getScreenWidth(), rl.getScreenHeight());

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
