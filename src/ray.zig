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
    const unit_direction = zm.normalize3(self.dir);
    const a = 0.5 * (unit_direction[1] + 1.0);
    return zm.f32x4s(1.0 - a) * zm.f32x4s(1.0) + zm.f32x4s(a) * zm.f32x4(0.5, 0.7, 1.0, 1.0);
}
