const std = @import("std");

const rayray = @import("rayray");
const Camera = rayray.Camera;
const Hittable = rayray.hittable.Hittable;
const HittableList = rayray.hittable.HittableList;
const material = rayray.material;
const Material = material.Material;
const Scene = rayray.Scene;
const Sphere = rayray.hittable.Sphere;
const tex = rayray.texture;
const zm = rayray.zmath;

camera: Camera.Options,
world: HittableList,
allocator: std.mem.Allocator,

pub fn scene(s: *Scene) !void {
    const c1 = try s.createTexture(tex.SolidColor.rgb(0.2, 0.3, 0.1));
    const c2 = try s.createTexture(tex.SolidColor.rgb(0.9, 0.9, 0.9));
    const checker_tex = try s.createTexture(tex.CheckerTexture.init(0.32, c1, c2));

    const checker = try s.createMaterial(checker_tex);

    try s.world.add(Hittable.initSphere(Sphere.init(zm.f32x4(0, -10, 0, 0), 10, checker)));
    try s.world.add(Hittable.initSphere(Sphere.init(zm.f32x4(0, 10, 0, 0), 10, checker)));

    try s.setCamera(Camera.Options{
        .aspect_ratio = 16.0 / 9.0,
        .image_width = 400,
        .samples_per_pixel = 100,
        .max_depth = 50,

        .vfov = 20,
        .look_from = zm.f32x4(13, 2, 3, 0),
        .look_at = zm.f32x4(0, 0, 0, 0),

        .defocus_angle = 0,
    });
}

pub fn deinit(self: *@This()) void {
    self.world.deinit();
}
