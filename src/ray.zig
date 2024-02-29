const std = @import("std");

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

pub fn at(self: *Ray, t: f32) zm.Vec {
    return self.orig + zm.f32x4s(t) * self.dir;
}
