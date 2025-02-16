const std = @import("std");
const rand = std.rand;

const rl = @import("raylib");

const draw = @import("draw.zig");

pub const Game = struct {
    pub const window_width = 1280;
    pub const window_height = 960;

    pub const Bounds = struct {
        right_bound: f32,
        left_bound: f32,
        bottom_bound: f32,
        top_bound: f32,
    };

    bounds: Bounds,
    delta_time: f32,

    pub fn new() Game {
        var game: Game = undefined;

        game.bounds.bottom_bound = 150;
        game.bounds.top_bound = -150;

        const win_width_as_fl = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const win_height_as_fl = @as(f32, @floatFromInt(rl.getScreenHeight()));
        const game_width = (win_width_as_fl / win_height_as_fl) *
            (game.bounds.bottom_bound + @abs(game.bounds.top_bound));

        game.bounds.left_bound = -game_width / 2;
        game.bounds.right_bound = game_width / 2;

        const win_width_over_game_width =
            @as(f32, @floatFromInt(rl.getScreenWidth())) /
            (game.bounds.right_bound + @abs(game.bounds.left_bound));

        const win_height_over_game_height =
            @as(f32, @floatFromInt(rl.getScreenHeight())) /
            (game.bounds.bottom_bound + @abs(game.bounds.top_bound));

        draw.setBounds(
            game.bounds,
            win_width_over_game_width,
            win_height_over_game_height,
        );

        game.delta_time = 0;
        return game;
    }

    /// Normalizes delta time so when the fps is 60, the return value is 1
    pub fn deltaTimeNormalized(self: Game) f32 {
        return self.delta_time * 60;
    }
};
