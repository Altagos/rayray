const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = b.addOptions();

    const strip = b.option(bool, "strip", "") orelse (optimize != .Debug);
    const max_depth = b.option(u64, "max-depth", "Set the max depth of the BVH tree") orelse std.math.maxInt(u64);
    options.addOption(u64, "max_depth", max_depth);

    const rayray = b.addModule("rayray", .{
        .root_source_file = b.path("src/rayray.zig"),
        .target = target,
        .optimize = optimize,
    });
    rayray.strip = strip;
    rayray.addOptions("build-options", options);

    addDeps(b, rayray);

    const exe = b.addExecutable(.{
        .name = "rayray",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.strip = strip;
    exe.root_module.addImport("rayray", rayray);

    const alib = b.dependency("a", .{
        .log_ignore_default = true,
    });
    exe.root_module.addImport("a", alib.module("a"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn addDeps(b: *std.Build, module: *std.Build.Module) void {
    const zmath = b.dependency("zmath", .{
        .optimize = .ReleaseFast,
        .enable_cross_platform_determinism = false,
    });
    module.addImport("zmath", zmath.module("root"));

    const zigimg = b.dependency("zigimg", .{
        .optimize = .ReleaseFast,
    });
    module.addImport("zigimg", zigimg.module("zigimg"));
}
