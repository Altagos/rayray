const zm = @import("zmath");

const AABB = @import("../AABB.zig");
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
bbox: AABB,

pub fn init(center: zm.Vec, radius: f32, mat: *Material) Sphere {
    const rvec = zm.f32x4s(radius);
    return Sphere{
        .center = center,
        .radius = @max(0, radius),
        .mat = mat,
        .bbox = AABB.initP(center - rvec, center + rvec),
    };
}

pub fn initMoving(center1: zm.Vec, center2: zm.Vec, radius: f32, mat: *Material) Sphere {
    const rvec = zm.f32x4s(radius);
    const box1 = AABB.initP(center1 - rvec, center1 + rvec);
    const box2 = AABB.initP(center2 - rvec, center2 + rvec);

    return Sphere{
        .center = center1,
        .radius = @max(0, radius),
        .mat = mat,
        .is_moving = true,
        .center_vec = center2 - center1,
        .bbox = AABB.initAB(&box1, &box2),
    };
}

pub inline fn boundingBox(self: *Sphere) AABB {
    // if (self.bbox) |bbox| {
    return self.bbox;
    // } else {
    //     const rvec = zm.f32x4s(self.radius);
    //     self.bbox = AABB.initP(self.center - rvec, self.center + rvec);
    //     return self.bbox.?;
    // }
}

pub fn hit(self: *const Sphere, r: *Ray, ray_t: IntervalF32) ?HitRecord {
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

    const sqrtd = zm.sqrt(discriminant);

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

pub inline fn sphereCenter(self: *const Sphere, time: f32) zm.Vec {
    return self.center + zm.f32x4s(time) * self.center_vec;
}
