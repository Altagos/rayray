const zm = @import("zmath");

const IntervalF32 = @import("../interval.zig").IntervalF32;
const Ray = @import("../Ray.zig");
const HitRecord = @import("../hittable.zig").HitRecord;
const Material = @import("../material.zig").Material;

const Sphere = @This();

center: zm.Vec,
radius: f32,
mat: *Material,
is_moving: bool = false,
center_vec: zm.Vec = zm.f32x4s(0),

pub fn initMoving(center1: zm.Vec, center2: zm.Vec, radius: f32, mat: *Material) Sphere {
    return .{
        .center = center1,
        .radius = @max(0, radius),
        .mat = mat,
        .is_moving = true,
        .center_vec = center2 - center1,
    };
}

pub fn hit(self: *Sphere, r: *Ray, ray_t: IntervalF32) ?HitRecord {
    const center = blk: {
        if (self.is_moving) {
            break :blk self.sphereCenter(r.tm);
        } else {
            break :blk self.center;
        }
    };
    const oc = r.orig - center;
    const a = zm.lengthSq3(r.dir)[0];
    const half_b = zm.dot3(oc, r.dir)[0];
    const c = zm.dot3(oc, oc)[0] - self.radius * self.radius;

    const discriminant = half_b * half_b - a * c;
    if (discriminant < 0) return null;

    const sqrtd = @sqrt(discriminant);

    // Find the nearest root that lies in the acceptable range
    var root = (-half_b - sqrtd) / a;
    if (!ray_t.surrounds(root)) {
        root = (-half_b + sqrtd) / a;
        if (!ray_t.surrounds(root)) return null;
    }

    var rec = HitRecord{
        .t = root,
        .p = r.at(root),
        .mat = self.mat,
    };

    const outward_normal = (rec.p - self.center) / zm.f32x4s(self.radius);
    rec.setFaceNormal(r, outward_normal);

    return rec;
}

pub fn sphereCenter(self: *Sphere, time: f32) zm.Vec {
    return self.center + zm.f32x4s(time) * self.center_vec;
}
