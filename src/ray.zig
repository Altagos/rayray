const zm = @import("zmath");

const Ray = @This();

orig: zm.Vec,
dir: zm.Vec,
tm: f32,

pub fn init(origin: zm.Vec, direction: zm.Vec) Ray {
    return Ray{
        .orig = origin,
        .dir = direction,
        .tm = 0,
    };
}

pub fn initT(origin: zm.Vec, direction: zm.Vec, tm: f32) Ray {
    return Ray{
        .orig = origin,
        .dir = direction,
        .tm = tm,
    };
}

pub inline fn at(self: *Ray, t: f32) zm.Vec {
    return self.orig + zm.f32x4s(t) * self.dir;
}
