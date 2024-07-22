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

    const rendering_time = timer.lap();

    std.log.info("Image rendered ({}s)", .{rendering_time / std.time.ns_per_s});

    try img.writeToFilePath("./out/out.png", .{ .png = .{} });
    std.log.info("Image saved to: ./out/out.png", .{});
}
