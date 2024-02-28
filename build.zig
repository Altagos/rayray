const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_spall = b.option(bool, "enable_spall", "Enable spall profiling") orelse false;
    const spall = b.dependency("spall", .{
        .enable = enable_spall,
    });

    const rayray = b.addModule("rayray", .{
        .root_source_file = .{ .path = "src/rayray.zig" },
        .target = target,
        .optimize = optimize,
    });
    rayray.addImport("spall", spall.module("spall"));

    addDeps(b, rayray);

    const exe = b.addExecutable(.{
        .name = "rayray",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
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

    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn addDeps(b: *std.Build, module: *std.Build.Module) void {
    const zmath = b.dependency("zmath", .{
        .enable_cross_platform_determinism = true,
    });
    module.addImport("zmath", zmath.module("zmath"));

    const zigimg = b.dependency("zigimg", .{});
    module.addImport("zigimg", zigimg.module("zigimg"));
}
