const rl = @import("raylib");
const rlm = rl.math;
const Vector2 = rl.Vector2;
const Matrix = rl.Matrix;

pub const Line = struct { point_a: Vector2, point_b: Vector2 };
const Bounds = @import("game.zig").Game.Bounds;

var bounds: Bounds = undefined;
var win_width_over_game_width: f32 = undefined;
var win_height_over_game_height: f32 = undefined;

pub fn setBounds(
    bnds: Bounds,
    winwidth_over_gamewidth: f32,
    winheight_over_gameheight: f32,
) void {
    bounds = bnds;
    win_width_over_game_width = winwidth_over_gamewidth;
    win_height_over_game_height = winheight_over_gameheight;
}

fn convertFromGameCoordsToWindowCoords(vec: Vector2) Vector2 {
    var result: Vector2 = undefined;
    result.x = (vec.x + bounds.right_bound) * win_width_over_game_width;
    result.y = (vec.y + bounds.bottom_bound) * win_height_over_game_height;
    return result;
}
const gameToWin = convertFromGameCoordsToWindowCoords;

pub fn drawLineVec2(point_a: Vector2, point_b: Vector2) void {
    rl.drawLineEx(gameToWin(point_a), gameToWin(point_b), 1, rl.Color.white);
}

pub fn drawLine(line: Line) void {
    rl.drawLineEx(
        gameToWin(line.point_a),
        gameToWin(line.point_b),
        1,
        rl.Color.white,
    );
}
