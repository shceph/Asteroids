const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{ .name = "asteroids", .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/main.zig" } }, .optimize = optimize, .target = target });

    // Add raylib-zig as a dependency
    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
    });

    // Import the main raylib module and raygui module
    const raylib = raylib_dep.module("raylib");
    const raygui = raylib_dep.module("raygui");

    // Import the raylib C library artifact
    const raylib_artifact = raylib_dep.artifact("raylib");

    // Link the raylib C library artifact
    exe.linkLibrary(raylib_artifact);

    // Add the raylib and raygui modules to the root module
    exe.root_module.addImport("raylib", raylib);
    exe.root_module.addImport("raygui", raygui);

    b.installArtifact(exe);

    // Copy assets folder after building
    const copy_assets = b.addInstallDirectory(.{
        .source_dir = b.path("assets"),
        .install_dir = .bin,
        .install_subdir = "assets",
    });

    b.getInstallStep().dependOn(&copy_assets.step);
}
