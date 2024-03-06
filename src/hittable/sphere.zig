const zm = @import("zmath");

const IntervalF32 = @import("a").interval.IntervalF32;
const Ray = @import("../ray.zig");
const HitRecord = @import("../hittable.zig").HitRecord;
const Material = @import("../material.zig").Material;

const Sphere = @This();

center: zm.Vec,
radius: f32,
mat: *Material,

pub fn hit(self: *Sphere, r: *Ray, ray_t: IntervalF32) ?HitRecord {
    const oc = r.orig - self.center;
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
