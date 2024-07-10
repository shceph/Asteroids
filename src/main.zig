const std = @import("std");
const math = std.math;
const rand = std.rand;

const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;
const Matrix  = rl.Matrix;

const Line = struct {
    pointA: Vector2,
    pointB: Vector2
};

const Game = struct {
    const windowWidth = 1280;
    const windowHeight = 960;

    rnd: rand.Xoshiro256,

    rightBound: f32,
    leftBound: f32,
    bottomBound: f32,
    topBound: f32,

    winWidthOverGameWidth: f32,
    winHeightOverGameHeight: f32,

    deltaTime: f32,

    fn init(self: *Game, fullscreen: bool) void {
        self.rnd = rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));

        self.bottomBound = 150;
        self.topBound = -150;

        var gameWidth: f32 = undefined;

        if (fullscreen) {
            gameWidth =
                (@as(f32, @floatFromInt(rl.getScreenWidth())) / @as(f32, @floatFromInt(rl.getScreenHeight())))
                * (self.bottomBound + @abs(self.topBound));
        } else {
            gameWidth =
                (@as(f32, @floatFromInt(windowWidth)) / @as(f32, @floatFromInt(windowHeight)))
                * (self.bottomBound + @abs(self.topBound));
        }

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

const Rocket = struct {
    const rocketSpeed = 4.0;

    pos: Vector2,
    angle: f32,

    fn new() Rocket {
        const rocket: Rocket = .{ .pos = ship.pos, .angle = ship.rot, };
        return rocket;
    }

    /// If returned false, the rocket is to be destroyed
    fn update(self: *Rocket) !bool {
        self.pos.x += rocketSpeed * @sin(-self.angle) * game.deltaTimeNormalized();
        self.pos.y += rocketSpeed * @cos(self.angle) * game.deltaTimeNormalized();

        if (!isPosInMap(self.pos)) {
            return false;
        }

        for (asteroids.items) |*astr| {
            if (rlm.vector2Distance(astr.pos, self.pos) <= Asteroid.radius(astr.size)) {
                if (astr.size == .small) {
                    astr.* = Asteroid.new();
                    return false;
                }

                const newSize: Asteroid.Size = if (astr.size == .large) .medium else .small;
                const astrPos = astr.pos;
                const astrVel = astr.velocity;

                astr.* = Asteroid.newFromDestroyed(astrPos, astrVel, newSize);
                try asteroids.append(Asteroid.newFromDestroyed(astrPos, astrVel, newSize));

                return false;
            }
        }

        return true;
    }
};

const Ship = struct {
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
    const engineIdleDrag = 0.014;
    const rotationSpeed = 4.0;
    const maxRockets = 5;

    shipLines: [7]Line,
    pos: Vector2,
    vel: Vector2,
    acc: Vector2,
    rot: f32,
    angleWhenEngineLastUsed: f32,
    engineWorking: bool,
    collided: bool,
    rockets: std.ArrayList(Rocket),

    const shipLinesRandVelocities = struct {
        var vels: [7]Vector2 = undefined;

        fn setRandVelocities() void {
            for (&vels) |*value| {
                value.x = (game.rnd.random().float(f32) - 0.5);
                value.y = (game.rnd.random().float(f32) - 0.5);
            }
        }
    };
    
    const lineVels = shipLinesRandVelocities;

    fn init(self: *Ship) !void {
        self.pos = .{ .x = 0, .y = 0 };
        self.vel = .{ .x = 0, .y = 0 };
        self.acc = .{ .x = 0, .y = 0 };
        self.rot = 0;
        self.angleWhenEngineLastUsed = 0;
        self.engineWorking = false;
        self.collided = false;
        self.rockets = try std.ArrayList(Rocket).initCapacity(std.heap.page_allocator, maxRockets);
        std.mem.copyForwards(Line, &self.shipLines, &defaultShipLines);
    }

    fn deinit(self: *Ship) void {
        self.rockets.deinit();
    }

    fn relive(self: *Ship) void {
        self.pos = .{ .x = 0, .y = 0 };
        self.vel = .{ .x = 0, .y = 0 };
        self.acc = .{ .x = 0, .y = 0 };
        self.rot = 0;
        self.angleWhenEngineLastUsed = 0;
        self.engineWorking = false;
        self.collided = false;
        self.rockets.clearRetainingCapacity();
        std.mem.copyForwards(Line, &self.shipLines, &defaultShipLines);
    }

    fn hasCollided(self: *Ship) void {
        if (self.collided) {
            return;
        }

        self.collided = true;
        self.acc = .{ .x = 0, .y = 0 };
        // self.vel = .{ .x = 0, .y = 0 };
        self.engineWorking = false;
        lineVels.setRandVelocities();
    }

    fn rotateLeftwards(self: *Ship) void {
        self.rot -= math.degreesToRadians(rotationSpeed) * game.deltaTimeNormalized();
    }

    fn rotateRightwards(self: *Ship) void {
        self.rot += math.degreesToRadians(rotationSpeed) * game.deltaTimeNormalized();
    }

    fn update(self: *Ship) !void {
        if (self.collided) {
            for (&self.shipLines, 0..) |*line, i| {
                line.pointA = line.pointA.add(lineVels.vels[i].scale(game.deltaTimeNormalized()));
                line.pointB = line.pointB.add(lineVels.vels[i].scale(game.deltaTimeNormalized()));
            }
        } else if (self.engineWorking) {
            ship.acc.x = @sin(-ship.rot) * engineWorkingAcc;
            ship.acc.y = @cos(ship.rot) * engineWorkingAcc;
        } else {
            if (ship.vel.x > engineIdleDrag or ship.vel.x < -engineIdleDrag) {
                ship.acc.x = -engineIdleDrag * @cos(ship.angleWhenEngineLastUsed);
            } else {
                ship.acc.x = 0;
            }

            if (ship.vel.y > engineIdleDrag or ship.vel.y < -engineIdleDrag) {
                ship.acc.y = -engineIdleDrag * @sin(ship.angleWhenEngineLastUsed);
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

        var i: usize = 0;

        while (i < self.rockets.items.len) {
            if (!try self.rockets.items[i].update()) {
                _ = self.rockets.swapRemove(i);
                continue;
            }

            i += 1;
        }

        if (self.collided) {
            return;
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

    fn shoot(self: *Ship) !void {
        const static = struct {
            var timeUpToLastShot: f64 = undefined;

            fn setTime() void {
                timeUpToLastShot = rl.getTime();
            }

            fn timeSinceLastShot() f64 {
                return rl.getTime() - timeUpToLastShot;
            }
        };

        const timeBetweenShots = 0.1;

        if (self.rockets.items.len == maxRockets or static.timeSinceLastShot() < timeBetweenShots) {
            return;
        }

        try self.rockets.append(Rocket.new());
        static.setTime();
    }

    fn draw(self: *Ship) void {
        const frameCount = struct {
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

        frameCount.update();

        var shipLines: [7]Line = undefined;
        std.mem.copyForwards(Line, &shipLines, self.shipLines[0..]);

        for (&shipLines) |*line| {
            line.pointA = ship.pos.add(rlm.vector2Rotate(line.pointA, ship.rot));
            line.pointB = ship.pos.add(rlm.vector2Rotate(line.pointB, ship.rot));
            line.pointA = gameToWin(line.pointA);
            line.pointB = gameToWin(line.pointB);
        }

        for (shipLines[0..5]) |line| {
            drawLine(line);
        }

        if (ship.engineWorking and frameCount.drawFire) {
            drawLine(shipLines[5]);
            drawLine(shipLines[6]);
        }

        const rocketLenght = 3.0;

        for (self.rockets.items) |rocket| {
            var line: Line = .{ 
                .pointA = .{ .x = 0, .y =  rocketLenght / 2.0 },
                .pointB = .{ .x = 0, .y = -rocketLenght / 2.0 },
            };

            line.pointA = line.pointA.rotate(rocket.angle);
            line.pointB = line.pointB.rotate(rocket.angle);
            line.pointA = line.pointA.add(rocket.pos);
            line.pointB = line.pointB.add(rocket.pos);
            line.pointA = gameToWin(line.pointA);
            line.pointB = gameToWin(line.pointB);

            drawLine(line);
        }
    }
};

var ship: Ship = undefined;

const Asteroid = struct {
    var pointsOnCircleSmallAst: [8]Vector2 = undefined;
    var pointsOnCircleMediumAst: [8]Vector2 = undefined;
    var pointsOnCircleLargeAst: [8]Vector2 = undefined;

    points: [8]Vector2,
    pos: Vector2,
    velocity: Vector2,
    size: Size,
    spawnSide: SpawnSide,

    const Size = enum {
        small,
        medium,
        large,
    };

    const SpawnSide = enum {
        top,
        bottom,
        left,
        right,
        check_for_all,
    };

    fn radius(size: Size) f32 {
        return switch (size) {
            .small => 4,
            .medium => 8,
            .large => 12
        };
    }

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

    fn initStruct() void {
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

        const rand_int = @mod(game.rnd.random().int(i32), 100);

        if (rand_int >= 90) {
            astr.size = .large;
        } else if (rand_int >= 20) {
            astr.size = .medium;
        } else {
            astr.size = .small;
        }

        astr.spawnSide = @enumFromInt(@mod(game.rnd.random().int(i32), 4));

        if (astr.spawnSide == .top) {
            astr.pos.x = (game.rnd.random().float(f32) - 0.5) * (game.rightBound + @abs(game.leftBound));
            astr.pos.y = game.topBound - radius(astr.size);
            astr.velocity.x = (game.rnd.random().float(f32) - 0.5) * 2;
            astr.velocity.y = (1 - astr.velocity.x);
        } else if (astr.spawnSide == .bottom) {
            astr.pos.x = (game.rnd.random().float(f32) - 0.5) * (game.rightBound + @abs(game.leftBound));
            astr.pos.y = game.bottomBound + radius(astr.size);
            astr.velocity.x = (game.rnd.random().float(f32) - 0.5) * 2;
            astr.velocity.y = (1 - astr.velocity.x) * (-1);
        } else if (astr.spawnSide == .left) {
            astr.pos.x = game.leftBound - radius(astr.size);
            astr.pos.y = (game.rnd.random().float(f32) - 0.5) * (game.bottomBound + @abs(game.topBound));
            astr.velocity.x = game.rnd.random().float(f32);
            astr.velocity.y = (1 - astr.velocity.x);
        } else if (astr.spawnSide == .right) {
            astr.pos.x = game.rightBound + radius(astr.size);
            astr.pos.y = (game.rnd.random().float(f32) - 0.5) * (game.bottomBound + @abs(game.topBound));
            astr.velocity.x = game.rnd.random().float(f32) * (-1);
            astr.velocity.y = (1 - astr.velocity.x) * (-1);
        }

        astr.velocity.x *= speedMultiplier(astr.size);
        astr.velocity.y *= speedMultiplier(astr.size);

        for (astr.points, 0..) |_, i| {
            // The random number is always positive, and I don't want
            // coordinates to only increase since it would be weird when
            // checking for collision as center wouldn't really be in center
            const multiplyXby1orMinus1: f32 =
                if (game.rnd.random().boolean()) -1 else 1;

            const multiplyYby1orMinus1: f32 =
                if (game.rnd.random().boolean()) -1 else 1;

            astr.points[i].x =
                Asteroid.pointsOnCircle(astr.size)[i].x
                + multiplyXby1orMinus1 * game.rnd.random().float(f32)
                * randomMultiplier(astr.size);

            astr.points[i].y =
                Asteroid.pointsOnCircle(astr.size)[i].y
                + multiplyYby1orMinus1 * game.rnd.random().float(f32)
                * randomMultiplier(astr.size);
        }

        return astr;
    }

    fn newFromDestroyed(pos: Vector2, parentAstrVel: Vector2, size: Size) Asteroid {
        var astr: Asteroid = .{
            .points = undefined,
            .pos = pos,
            .velocity = undefined,
            .size = size,
            .spawnSide = .check_for_all
        };

        astr.velocity = parentAstrVel;
        astr.velocity.x += game.rnd.random().float(f32) / 5;
        astr.velocity.y += (1.0 / 5.0) - astr.velocity.x;

        for (astr.points, 0..) |_, i| {
            const multiplyXby1orMinus1: f32 =
                if (game.rnd.random().boolean()) -1 else 1;

            const multiplyYby1orMinus1: f32 =
                if (game.rnd.random().boolean()) -1 else 1;

            astr.points[i].x =
                Asteroid.pointsOnCircle(astr.size)[i].x
                + multiplyXby1orMinus1 * game.rnd.random().float(f32)
                * randomMultiplier(astr.size);

            astr.points[i].y =
                Asteroid.pointsOnCircle(astr.size)[i].y
                + multiplyYby1orMinus1 * game.rnd.random().float(f32)
                * randomMultiplier(astr.size);
        }

        return astr;
    }

    fn checkIfOutOfBounds(self: *Asteroid, top: bool, bottom: bool, left: bool, right: bool) bool {
        if ((top and self.pos.y < game.topBound) or
            (bottom and self.pos.y > game.bottomBound) or
            (left and self.pos.x < game.leftBound) or
            (right and self.pos.x > game.rightBound))
        {
            return true;
        }

        return false;
    }

    /// Returns true if swapRemove was used on 'asteroids'
    fn update(self: *Asteroid, index: usize) bool {
        self.pos.x += self.velocity.x * game.deltaTimeNormalized();
        self.pos.y += self.velocity.y * game.deltaTimeNormalized();

        if (rl.math.vector2Distance(self.pos, ship.pos) <= radius(self.size)) {
            ship.hasCollided();
        }

        if ((self.spawnSide == .top and self.checkIfOutOfBounds(false, true, true, true)) or
            (self.spawnSide == .bottom and self.checkIfOutOfBounds(true, false, true, true)) or
            (self.spawnSide == .left and self.checkIfOutOfBounds(true, true, false, true)) or
            (self.spawnSide == .right and self.checkIfOutOfBounds(true, true, true, false)) or
            (self.spawnSide == .check_for_all and self.checkIfOutOfBounds(true, true, true, true)))
        {
            if (asteroids.items.len > minAsteroids) {
                _ = asteroids.swapRemove(index);
                return true;
            } else {
                self.* = new();
            }
        }

        return false;
    }
};

const minAsteroids = 25;
var asteroids: std.ArrayList(Asteroid) = undefined;

fn init(fullscreen: bool) !void {
    game.init(fullscreen);
    try ship.init();

    asteroids = try std.ArrayList(Asteroid).initCapacity(std.heap.page_allocator, 60);

    for (0..minAsteroids) |_| {
        try asteroids.append(Asteroid.new());
    }
}

fn update() !void {
    try ship.update();

    var i: usize = 0;

    while (i < asteroids.items.len) {
        if (asteroids.items[i].update(i)) {
            continue;
        }

        i += 1;
    }
}

fn input() !void {
    if (ship.collided) {
        if (rl.isKeyDown(.key_enter)) {
            ship.relive();
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

    if (rl.isKeyDown(.key_space)) {
        try ship.shoot();
    }
}

fn drawAsteroids() void {
    for (asteroids.items) |astr| {
        for (0..astr.points.len - 1) |i| {
            const pointA = gameToWin(astr.pos.add(astr.points[i]));
            const pointB = gameToWin(astr.pos.add(astr.points[i + 1]));
            drawLineVec2(pointA, pointB);
        }

        const pointA = gameToWin(astr.pos.add(astr.points[0]));
        const pointB = gameToWin(astr.pos.add(astr.points[astr.points.len - 1]));
        drawLineVec2(pointA, pointB);
    }
}

fn convertFromGameToWindowCoords(vec: Vector2) Vector2 {
    var result: Vector2 = undefined;
    result.x = (vec.x + game.rightBound) * game.winWidthOverGameWidth;
    result.y = (vec.y + game.bottomBound) * game.winHeightOverGameHeight;
    return result;
}

const gameToWin = convertFromGameToWindowCoords;

fn isPosInMap(pos: Vector2) bool {
    if (pos.x < game.leftBound or pos.x > game.rightBound or
        pos.y < game.topBound or pos.y > game.bottomBound)
    {
        return false;
    }

    return true;
}

fn drawLineVec2(pointA: Vector2, pointB: Vector2) void {
    rl.drawLineEx(pointA, pointB, 1, rl.Color.white);
}

fn drawLine(line: Line) void {
    rl.drawLineEx(line.pointA, line.pointB, 1, rl.Color.white);
}

pub fn main() !void {
    rl.setConfigFlags(.{ .vsync_hint = true });

    const fullscreen = false;
    rl.initWindow(Game.windowWidth, Game.windowHeight, "Asteroids");
    defer rl.closeWindow();
    rl.setWindowSize(Game.windowWidth, Game.windowHeight);

    // const fullscreen = true;
    // rl.initWindow(rl.getScreenWidth(), rl.getScreenHeight(), "Asteroids");
    // defer rl.closeWindow();
    // rl.toggleFullscreen();
    // rl.setWindowSize(rl.getScreenWidth(), rl.getScreenHeight());

    rl.setTargetFPS(60);

    Asteroid.initStruct();
    try init(fullscreen);

    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        game.deltaTime = rl.getFrameTime();
        // Update
        //---------------------------------------------------------------------
        try input();
        try update();

        // Draw
        //---------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        ship.draw();
        drawAsteroids();
    }

    ship.deinit();
    asteroids.deinit();
}
