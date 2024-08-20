const std = @import("std");

const aa = @import("a");

const rayray = @import("rayray");
const Hittable = rayray.hittable.Hittable;
const HittableList = rayray.hittable.HittableList;
const Material = rayray.material.Material;
const Sphere = rayray.hittable.Sphere;
const zm = rayray.zmath;

const scences = @import("scences.zig");

pub const std_options = .{
    .log_level = .debug,
    .logFn = aa.log.logFn,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Setting up the world
    var scence = try scences.inOneWeekend(allocator);
    defer scence.deinit();

    std.log.info("World created", .{});

    // Raytracing part
    var raytracer = try rayray.Raytracer.init(allocator, scence.world, .{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
        .samples_per_pixel = 50,
        .max_depth = 50,

        .vfov = 20,
        .look_from = zm.f32x4(20, 6, 6, 0),
        .look_at = zm.f32x4(0, 0, 0, 0),

        .defocus_angle = 0.6,
        .focus_dist = 18,
    });
    defer raytracer.deinit();

    var timer = try std.time.Timer.start();

    const img = try raytracer.render();

    printRenderTime(timer.lap());

    try img.writeToFilePath("./out/out.png", .{ .png = .{} });
    std.log.info("Image saved to: ./out/out.png", .{});
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
