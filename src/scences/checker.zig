const std = @import("std");

const rayray = @import("rayray");
const Camera = rayray.Camera;
const Hittable = rayray.hittable.Hittable;
const HittableList = rayray.hittable.HittableList;
const Material = rayray.material.Material;
const Sphere = rayray.hittable.Sphere;
const tex = rayray.texture;
const zm = rayray.zmath;

camera: Camera.Options,
world: HittableList,
allocator: std.mem.Allocator,

pub fn scene(allocator: std.mem.Allocator) !@This() {
    var world = HittableList.init(allocator);

    const c1 = try allocator.create(tex.Texture);
    c1.* = tex.Texture{ .solid_color = tex.SolidColor.rgb(0.2, 0.3, 0.1) };
    const c2 = try allocator.create(tex.Texture);
    c2.* = tex.Texture{ .solid_color = tex.SolidColor.rgb(0.9, 0.9, 0.9) };

    const checker = try allocator.create(Material);
    checker.* = Material.lambertian(tex.Texture{ .checker_texture = tex.CheckerTexture.init(0.32, c1, c2) });

    try world.add(Hittable.sphere("s1", Sphere.init(zm.f32x4(0, -10, 0, 0), 10, checker)));
    try world.add(Hittable.sphere("s2", Sphere.init(zm.f32x4(0, 10, 0, 0), 10, checker)));

    return .{ .allocator = allocator, .world = world, .camera = Camera.Options{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
        .samples_per_pixel = 100,
        .max_depth = 50,

        .vfov = 20,
        .look_from = zm.f32x4(13, 2, 3, 0),
        .look_at = zm.f32x4(0, 0, 0, 0),

        .defocus_angle = 0,
    } };
}

pub fn deinit(self: *@This()) void {
    self.world.deinit();
}
