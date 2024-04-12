const std = @import("std");

const aa = @import("a");
const spall = @import("spall");
const zm = @import("zmath");

const rayray = @import("rayray");
const Hittable = rayray.hittable.Hittable;
const HittableList = rayray.hittable.HittableList;
const Material = rayray.material.Material;
const Sphere = rayray.hittable.Sphere;

pub const std_options = .{
    .log_level = .debug,
    .logFn = aa.log.logFn,
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
    var material_ground = Material.lambertian(zm.f32x4(0.5, 0.5, 0.5, 1.0));

    var world = HittableList.init(allocator);
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(0, -1000, 0, 0), .radius = 1000, .mat = &material_ground }));

    var a: isize = -11;
    while (a < 11) : (a += 1) {
        var b: isize = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = rayray.util.randomF32();
            const center = zm.f32x4(
                @as(f32, @floatFromInt(a)) + 0.9 * rayray.util.randomF32(),
                0.2,
                @as(f32, @floatFromInt(b)) + 0.9 * rayray.util.randomF32(),
                0,
            );

            if (zm.length3(center - zm.f32x4(4, 0.2, 0, 0))[0] > 0.9) {
                const material = try allocator.create(Material);

                if (choose_mat < 0.8) {
                    // diffuse
                    const albedo = rayray.util.randomVec3() * rayray.util.randomVec3() + zm.f32x4(0, 0, 0, 1);
                    material.* = Material.lambertian(albedo);
                    try world.add(Hittable.sphere(Sphere{ .center = center, .radius = 0.2, .mat = material }));
                } else if (choose_mat < 0.95) {
                    // metal
                    const albedo = rayray.util.randomVec3M(0.5, 1) + zm.f32x4(0, 0, 0, 1);
                    const fuzz = rayray.util.randomF32M(0, 0.5);
                    material.* = Material.metal(albedo, fuzz);
                    try world.add(Hittable.sphere(Sphere{ .center = center, .radius = 0.2, .mat = material }));
                } else {
                    // glass
                    material.* = Material.dielectric(1.5);
                    try world.add(Hittable.sphere(Sphere{ .center = center, .radius = 0.2, .mat = material }));
                }
            }
        }
    }

    var material1 = Material.dielectric(1.5);
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(0, 1, 0, 0), .radius = 1, .mat = &material1 }));

    var material2 = Material.lambertian(zm.f32x4(0.4, 0.2, 0.1, 1));
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(-4, 1, 0, 0), .radius = 1, .mat = &material2 }));

    var material3 = Material.metal(zm.f32x4(0.7, 0.6, 0.5, 1), 0);
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(4, 1, 0, 0), .radius = 1, .mat = &material3 }));

    const s = spall.trace(@src(), "Raytracer", .{});

    // Raytracing part
    var raytracer = try rayray.Raytracer.init(allocator, world, .{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 1200,
        .samples_per_pixel = 500,
        .max_depth = 50,

        .vfov = 20,
        .look_from = zm.f32x4(13, 2, 3, 0),
        .look_at = zm.f32x4(0, 0, 0, 0),

        .defocus_angle = 0.6,
        .focus_dist = 10,
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
    std.log.info("Image saved to: ./out/out.png", .{});
}
