const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_spall = b.option(bool, "enable_spall", "Enable spall profiling") orelse false;
    const spall = b.dependency("spall", .{
        .enable = enable_spall,
    });

    const strip = b.option(bool, "strip", "") orelse false;

    const rayray = b.addModule("rayray", .{
        .root_source_file = .{ .path = "src/rayray.zig" },
        .target = target,
        .optimize = optimize,
    });
    rayray.strip = strip;

    rayray.addImport("spall", spall.module("spall"));

    addDeps(b, rayray);

    const exe = b.addExecutable(.{
        .name = "rayray",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.strip = strip;

    addDeps(b, &exe.root_module);
    exe.root_module.addImport("spall", spall.module("spall"));
    exe.root_module.addImport("rayray", rayray);

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
    const alib = b.dependency("a", .{
        .log_ignore_default = true,
    });
    module.addImport("a", alib.module("a"));

    const zmath = b.dependency("zmath", .{
        .enable_cross_platform_determinism = true,
    });
    module.addImport("zmath", zmath.module("root"));

    const zigimg = b.dependency("zigimg", .{});
    module.addImport("zigimg", zigimg.module("zigimg"));
}
