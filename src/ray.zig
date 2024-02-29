const std = @import("std");

const zm = @import("zmath");

const hittable = @import("hittable.zig");
const Ray = @This();

orig: zm.Vec,
dir: zm.Vec,

pub fn init(origin: zm.Vec, direction: zm.Vec) Ray {
    return Ray{
        .orig = origin,
        .dir = direction,
    };
}

pub fn at(self: *Ray, t: f32) zm.Vec {
    return self.orig + zm.f32x4s(t) * self.dir;
}

pub fn color(r: *Ray, world: *hittable.HittableList) zm.Vec {
    if (world.hit(r, 0, std.math.inf(f32))) |rec| {
        return zm.f32x4s(0.5) * (rec.normal + zm.f32x4(1, 1, 1, 1));
    }

    const unit_direction = zm.normalize3(r.dir);
    const a = 0.5 * (unit_direction[1] + 1.0);
    return zm.f32x4s(1.0 - a) * zm.f32x4s(1.0) + zm.f32x4s(a) * zm.f32x4(0.5, 0.7, 1.0, 1.0);
}

fn hitSphere(center: zm.Vec, radius: f32, r: *Ray) f32 {
    const oc = r.orig - center;
    const a = zm.lengthSq3(r.dir)[0];
    const half_b = zm.dot3(oc, r.dir)[0];
    const c = zm.dot3(oc, oc)[0] - radius * radius;
    const discriminant = half_b * half_b - a * c;

    if (discriminant < 0) {
        return -1.0;
    } else {
        return (-half_b - @sqrt(discriminant)) / a;
    }
}
