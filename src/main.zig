const std = @import("std");

const a = @import("a");
const spall = @import("spall");
const zm = @import("zmath");

const rayray = @import("rayray");
const Hittable = rayray.hittable.Hittable;
const HittableList = rayray.hittable.HittableList;
const Material = rayray.material.Material;
const Sphere = rayray.hittable.Sphere;

pub const std_options = .{
    .log_level = .debug,
    .logFn = a.log.logFn,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try spall.init("./out/trace.spall");
    defer spall.deinit();

    spall.init_thread();
    defer spall.deinit_thread();

    // Setting up the world
    var material_ground = Material.lambertian(zm.f32x4(0.8, 0.8, 0.0, 1.0));
    var material_center = Material.lambertian(zm.f32x4(0.7, 0.3, 0.3, 1.0));
    var material_left = Material.metal(zm.f32x4(0.8, 0.8, 0.8, 1.0), 0.0);
    var material_right = Material.metal(zm.f32x4(0.8, 0.6, 0.2, 1.0), 1.0);

    var world = HittableList.init(allocator);
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(0, -100.5, -1, 0), .radius = 100, .mat = &material_ground }));
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(0, 0, -1, 0), .radius = 0.5, .mat = &material_center }));
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(-1, 0, -1, 0), .radius = 0.5, .mat = &material_left }));
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(1, 0, -1, 0), .radius = 0.5, .mat = &material_right }));

    const s = spall.trace(@src(), "Raytracer", .{});

    // Raytracing part
    var raytracer = try rayray.Raytracer.init(allocator, world, .{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
        .samples_per_pixel = 100,
        .max_depth = 50,
    });
    defer raytracer.deinit();

    var timer = try std.time.Timer.start();

    const img = try raytracer.render();

    const rendering_time = timer.lap();

    std.log.info("Image rendered ({}s)", .{rendering_time / std.time.ns_per_s});

    s.end();

    // Saving to file
    const s_saving = spall.trace(@src(), "Write Image", .{});
    defer s_saving.end();

    try img.writeToFilePath("./out/out.png", .{ .png = .{} });
    std.log.info("Image saved to: ./out/out.ong", .{});
}
