const zm = @import("zmath");

const Ray = @This();

orig: zm.Vec,
dir: zm.Vec,

pub fn init(origin: zm.Vec, direction: zm.Vec) Ray {
    return Ray{
        .orig = origin,
        .dir = direction,
    };
}

pub fn color(self: *Ray) zm.Vec {
    if (hit_sphere(zm.f32x4(0, 0, -1, 0), 0.5, self)) {
        return zm.f32x4(1, 0, 0, 1);
    }

    const unit_direction = zm.normalize3(self.dir);
    const a = 0.5 * (unit_direction[1] + 1.0);
    return zm.f32x4s(1.0 - a) * zm.f32x4s(1.0) + zm.f32x4s(a) * zm.f32x4(0.5, 0.7, 1.0, 1.0);
}

fn hit_sphere(center: zm.Vec, radius: f32, r: *Ray) bool {
    const oc = r.orig - center;
    const a = zm.dot3(r.dir, r.dir)[0];
    const b = 2.0 * zm.dot3(oc, r.dir)[0];
    const c = zm.dot3(oc, oc)[0] - radius * radius;
    const discriminant = b * b - 4 * a * c;
    return discriminant >= 0;
}
