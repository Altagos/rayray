const std = @import("std");
const Options = std.Options;

const aa = @import("a");

const rayray = @import("rayray");
const Hittable = rayray.hittable.Hittable;
const HittableList = rayray.hittable.HittableList;
const Material = rayray.material.Material;
const Sphere = rayray.hittable.Sphere;
const zm = rayray.zmath;

const build_options = rayray.build_options;

const scenes = @import("scenes.zig");

pub const std_options = Options{
    .log_level = .debug,
    .logFn = aa.log.logFn,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const allocator = gpa.allocator();
    // defer {
    //     const deinit_status = gpa.deinit();
    //     //fail test; can't try in defer as defer is executed after we return
    //     if (deinit_status == .leak) @panic("LEAK");
    // }

    // Setting up the world
    var scene = rayray.Scene.init(allocator);
    defer scene.deinit();

    try scenes.checker(&scene);

    std.log.info("World created", .{});

    // Raytracing part
    var raytracer = try rayray.Raytracer.init(allocator, scene);
    defer raytracer.deinit();

    var timer = try std.time.Timer.start();

    const img = try raytracer.render();

    printRenderTime(timer.lap());

    try img.writeToFilePath(build_options.output, .{ .png = .{} });
    std.log.info("Image saved to: {s}", .{build_options.output});
}

fn printRenderTime(t: u64) void {
    var rt = t;

    const days = rt / std.time.ns_per_day;
    rt = rt - (days * std.time.ns_per_day);

    const hours = rt / std.time.ns_per_hour;
    rt = rt - (hours * std.time.ns_per_hour);

    const minutes = rt / std.time.ns_per_min;
    rt = rt - (minutes * std.time.ns_per_min);

    const seconds = rt / std.time.ns_per_s;
    rt = rt - (seconds * std.time.ns_per_s);

    const ms = rt / std.time.ns_per_ms;
    rt = rt - (ms * std.time.ns_per_ms);

    // std.log.info("Image rendered ({}s)", .{rendering_time / std.time.ns_per_s});
    if (days == 0) {
        std.log.info("Image rendered in: {}h {}m {}s {}ms", .{ hours, minutes, seconds, ms });
    } else {
        std.log.info("Image rendered in: {}d {}h {}m {}s {}ms", .{ days, hours, minutes, seconds, ms });
    }
}
