const std = @import("std");

const zm = @import("zmath");

const rayray = @import("rayray");
const Hittable = rayray.hittable.Hittable;
const HittableList = rayray.hittable.HittableList;
const Material = rayray.material.Material;
const Sphere = rayray.hittable.Sphere;
const BVH = rayray.hittable.BVH;

world: HittableList,
allocator: std.mem.Allocator,

pub fn scene(allocator: std.mem.Allocator) !@This() {
    var world = HittableList.init(allocator);

    const material_ground = try allocator.create(Material);
    material_ground.* = Material.lambertian(zm.f32x4(0.5, 0.5, 0.5, 1.0));
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(0, -1000, 0, 0), .radius = 1000, .mat = material_ground }));

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

    const material1 = try allocator.create(Material);
    material1.* = Material.dielectric(1.5);
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(0, 1, 0, 0), .radius = 1, .mat = material1 }));

    const material2 = try allocator.create(Material);
    material2.* = Material.lambertian(zm.f32x4(0.4, 0.2, 0.1, 1));
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(-4, 1, 0, 0), .radius = 1, .mat = material2 }));

    const material3 = try allocator.create(Material);
    material3.* = Material.metal(zm.f32x4(0.7, 0.6, 0.5, 1), 0);
    try world.add(Hittable.sphere(Sphere{ .center = zm.f32x4(4, 1, 0, 0), .radius = 1, .mat = material3 }));

    var world2 = HittableList.init(allocator);
    try world2.add(Hittable.bvh(BVH.initL(&world)));
    return .{ .allocator = allocator, .world = world2 };
}

pub fn deinit(self: *@This()) void {
    self.world.deinit();
}
