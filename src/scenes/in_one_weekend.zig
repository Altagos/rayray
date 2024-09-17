const std = @import("std");

const rayray = @import("rayray");
const Camera = rayray.Camera;
const Hittable = rayray.hittable.Hittable;
const HittableList = rayray.hittable.HittableList;
const mat = rayray.material;
const Material = rayray.material.Material;
const Scene = rayray.Scene;
const Sphere = rayray.hittable.Sphere;
const zm = rayray.zmath;

camera: Camera.Options,
world: HittableList,
allocator: std.mem.Allocator,

pub fn scene(s: *Scene) !void {
    // var world = HittableList.init(allocator);

    const material_ground = try s.createMaterial(zm.f32x4(0.5, 0.5, 0.5, 1.0));
    // material_ground.* = Material.initLambertianS();
    try s.world.add(Hittable.initSphere(Sphere.init(zm.f32x4(0, -1000, 0, 0), 1000, material_ground)));

    const a_max = 11;
    const b_max = 11;

    var a: isize = -a_max;
    while (a < a_max) : (a += 1) {
        var b: isize = -b_max;
        while (b < b_max) : (b += 1) {
            const choose_mat = rayray.util.randomF32();
            const center = zm.f32x4(
                @as(f32, @floatFromInt(a)) + 0.9 * rayray.util.randomF32(),
                0.2,
                @as(f32, @floatFromInt(b)) + 0.9 * rayray.util.randomF32(),
                0,
            );

            if (zm.length3(center - zm.f32x4(4, 0.2, 0, 0))[0] > 0.9) {
                // const material = try allocator.create(Material);

                if (choose_mat < 0.8) {
                    // diffuse
                    const albedo = rayray.util.randomVec3() * rayray.util.randomVec3() + zm.f32x4(0, 0, 0, 1);
                    const material = try s.createMaterial(albedo);
                    const center2 = center + zm.f32x4(0, rayray.util.randomF32M(0, 0.5), 0, 0);
                    try s.world.add(Hittable.initSphere(Sphere.initMoving(center, center2, 0.2, material)));
                } else if (choose_mat < 0.95) {
                    // metal
                    const albedo = rayray.util.randomVec3M(0.5, 1) + zm.f32x4(0, 0, 0, 1);
                    const fuzz = rayray.util.randomF32M(0, 0.5);
                    const material = try s.createMaterial(mat.Metal.init(albedo, fuzz));
                    try s.world.add(Hittable.initSphere(Sphere.init(center, 0.2, material)));
                } else {
                    // glass
                    const material = try s.createMaterial(mat.Dielectric{ .refraction_index = 1.5 });
                    try s.world.add(Hittable.initSphere(Sphere.init(center, 0.2, material)));
                }
            }
        }
    }

    // const material1 = try allocator.create(Material);
    // material1.* = Material.initDielectric(1.5);
    const material1 = try s.createMaterial(mat.Dielectric{ .refraction_index = 1.5 });
    try s.world.add(Hittable.initSphere(Sphere.init(zm.f32x4(0, 1, 0, 0), 1, material1)));

    // const material2 = try allocator.create(Material);
    // material2.* = Material.initLambertianS(zm.f32x4(0.4, 0.2, 0.1, 1));
    const material2 = try s.createMaterial(zm.f32x4(0.4, 0.2, 0.1, 1));
    try s.world.add(Hittable.initSphere(Sphere.init(zm.f32x4(-4, 1, 0, 0), 1, material2)));

    // const material3 = try allocator.create(Material);
    // material3.* = Material.initMetal(zm.f32x4(0.7, 0.6, 0.5, 1), 0);
    const material3 = try s.createMaterial(mat.Metal.init(zm.f32x4(0.7, 0.6, 0.5, 1), 0));
    try s.world.add(Hittable.initSphere(Sphere.init(zm.f32x4(4, 1, 0, 0), 1, material3)));

    // try world.add(Hittable.sphere("One: Dielectric", Sphere.init(zm.f32x4(0, 1, 0, 0), 1, material2)));

    try s.setCamera(.{
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
}

pub fn deinit(self: *@This()) void {
    self.world.deinit();
}
