const std = @import("std");
const random = std.crypto.random;

const zm = @import("zmath");

/// Returns a random real in [0,1).
pub inline fn randomF32() f32 {
    return random.float(f32);
}

/// Returns a random real in [min,max).
pub inline fn randomF32M(min: f32, max: f32) f32 {
    return min + (max - min) * randomF32();
}

pub inline fn randomVec2() zm.Vec {
    return zm.f32x4(randomF32, randomF32, 0, 0);
}

pub inline fn randomVec3() zm.Vec {
    return zm.f32x4(randomF32, randomF32, randomF32, 0);
}

pub inline fn randomVec() zm.Vec {
    return zm.f32x4(randomF32, randomF32, randomF32, randomF32);
}

pub inline fn randomVec2M(min: f32, max: f32) zm.Vec {
    return zm.f32x4(randomF32M(min, max), randomF32M(min, max), 0, 0);
}

pub inline fn randomVec3M(min: f32, max: f32) zm.Vec {
    return zm.f32x4(randomF32M(min, max), randomF32M(min, max), randomF32M(min, max), 0);
}

pub inline fn randomVecM(min: f32, max: f32) zm.Vec {
    return zm.f32x4(randomF32M(min, max), randomF32M(min, max), randomF32M(min, max), randomF32M(min, max));
}

pub inline fn randomInUnitSphere() zm.Vec {
    while (true) {
        const p = randomVec3M(-1.0, 1.0);
        if (zm.lengthSq3(p)[0] < 1.0) return p;
    }
}

pub inline fn randomUnitVec() zm.Vec {
    return zm.normalize3(randomInUnitSphere());
}

pub inline fn randomOnHemisphere(normal: zm.Vec) zm.Vec {
    const on_unit_sphere = randomUnitVec();
    return if (zm.dot3(on_unit_sphere, normal)[0] > 0.0) // In the same hemisphere as the normal
        on_unit_sphere
    else
        -on_unit_sphere;
}
