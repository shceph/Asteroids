const std = @import("std");

const rl = @import("raylib");
const Vector2 = rl.Vector2;

const Line = @import("draw.zig").Line;

pub const Alien = struct {
    pub const alien_default_lines: [10]Line = .{
        .{ .point_a = .{ .x = -10.0, .y = 0.0 }, .point_b = .{ .x = 10.0, .y = 0.0 } },
        .{ .point_a = .{ .x = -8.0, .y = 0.0 }, .point_b = .{ .x = -6.0, .y = 2.0 } },
        .{ .point_a = .{ .x = 8.0, .y = 0.0 }, .point_b = .{ .x = 6.0, .y = 2.0 } },
        .{ .point_a = .{ .x = -6.0, .y = 2.0 }, .point_b = .{ .x = 6.0, .y = 2.0 } },

        .{ .point_a = .{ .x = -10.0, .y = 0.0 }, .point_b = .{ .x = -8.0, .y = -4.0 } },
        .{ .point_a = .{ .x = 10.0, .y = 0.0 }, .point_b = .{ .x = 8.0, .y = -4.0 } },

        .{ .point_a = .{ .x = -8.0, .y = -4.0 }, .point_b = .{ .x = 8.0, .y = -4.0 } },
        .{ .point_a = .{ .x = -4.0, .y = -4.0 }, .point_b = .{ .x = -2.0, .y = -6.0 } },
        .{ .point_a = .{ .x = 4.0, .y = -4.0 }, .point_b = .{ .x = 2.0, .y = -6.0 } },
        .{ .point_a = .{ .x = -2.0, .y = -6.0 }, .point_b = .{ .x = 2.0, .y = -6.0 } },
    };

    pos: Vector2,
};
