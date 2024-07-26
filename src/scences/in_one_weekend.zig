const std = @import("std");

const rayray = @import("rayray");
const Hittable = rayray.hittable.Hittable;
const HittableList = rayray.hittable.HittableList;
const Material = rayray.material.Material;
const Sphere = rayray.hittable.Sphere;
const zm = rayray.zmath;

world: HittableList,
allocator: std.mem.Allocator,

pub fn scene(allocator: std.mem.Allocator) !@This() {
    var world = HittableList.init(allocator);

    const material_ground = try allocator.create(Material);
    material_ground.* = Material.lambertian(zm.f32x4(0.5, 0.5, 0.5, 1.0));
    try world.add(Hittable.sphere("Ground", Sphere.init(zm.f32x4(0, -1000, 0, 0), 1000, material_ground)));

    const a_max = 30;
    const b_max = 30;
    const c = 1.7;

    var a: isize = -a_max;
    while (a < a_max) : (a += 1) {
        var b: isize = -b_max;
        while (b < b_max) : (b += 1) {
            const choose_mat = rayray.util.randomF32();
            const center = zm.f32x4(
                @as(f32, @floatFromInt(a)) / c + 0.9 * rayray.util.randomF32(),
                0.2,
                @as(f32, @floatFromInt(b)) / c + 0.9 * rayray.util.randomF32(),
                0,
            );

            if (zm.length3(center - zm.f32x4(4, 0.2, 0, 0))[0] > 0.9) {
                const material = try allocator.create(Material);

                if (choose_mat < 0.8) {
                    // diffuse
                    const albedo = rayray.util.randomVec3() * rayray.util.randomVec3() + zm.f32x4(0, 0, 0, 1);
                    material.* = Material.lambertian(albedo);
                    const center2 = center + zm.f32x4(0, rayray.util.randomF32M(0, 0.5), 0, 0);
                    try world.add(Hittable.sphere("Lambertian", Sphere.initMoving(center, center2, 0.2, material)));
                } else if (choose_mat < 0.95) {
                    // metal
                    const albedo = rayray.util.randomVec3M(0.5, 1) + zm.f32x4(0, 0, 0, 1);
                    const fuzz = rayray.util.randomF32M(0, 0.5);
                    material.* = Material.metal(albedo, fuzz);
                    try world.add(Hittable.sphere("Metal", Sphere.init(center, 0.2, material)));
                } else {
                    // glass
                    material.* = Material.dielectric(1.5);
                    try world.add(Hittable.sphere("Dielectric", Sphere.init(center, 0.2, material)));
                }
            }
        }
    }

    const material1 = try allocator.create(Material);
    material1.* = Material.dielectric(1.5);
    // try world.add(Hittable.sphere("One: Dielectric", Sphere{ .center = zm.f32x4(0, 1, 0, 0), .radius = 1, .mat = material1 }));

    const material2 = try allocator.create(Material);
    material2.* = Material.lambertian(zm.f32x4(0.4, 0.2, 0.1, 1));
    try world.add(Hittable.sphere("Two: Lambertian", Sphere.init(zm.f32x4(-4, 1, 0, 0), 1, material1)));

    const material3 = try allocator.create(Material);
    material3.* = Material.metal(zm.f32x4(0.7, 0.6, 0.5, 1), 0);
    try world.add(Hittable.sphere("Three: Metal", Sphere.init(zm.f32x4(4, 1, 0, 0), 1, material3)));

    try world.add(Hittable.sphere("One: Dielectric", Sphere.init(zm.f32x4(0, 1, 0, 0), 1, material2)));

    return .{ .allocator = allocator, .world = world };
}

pub fn deinit(self: *@This()) void {
    self.world.deinit();
}
