const random = @import("std").crypto.random;
const math = @import("std").math;

const zm = @import("zmath");

pub inline fn degreesToRadians(degrees: f32) f32 {
    return degrees * math.pi / 180.0;
}

/// Returns a random real in [0,1).
pub inline fn randomF32() f32 {
    return random.float(f32);
}

/// Returns a random real in [min,max).
pub inline fn randomF32M(min: f32, max: f32) f32 {
    return min + (max - min) * randomF32();
}

/// Returns a random real in [0,1).
pub inline fn randomI32() i32 {
    return random.float(i32);
}

/// Returns a random real in [min,max).
pub inline fn randomI32M(min: i32, max: i32) i32 {
    return min + (max - min) * randomI32();
}

pub inline fn randomVec2() zm.Vec {
    return zm.f32x4(randomF32(), randomF32(), 0, 0);
}

pub inline fn randomVec3() zm.Vec {
    return zm.f32x4(randomF32(), randomF32(), randomF32(), 0);
}

pub inline fn randomVec() zm.Vec {
    return zm.f32x4(randomF32(), randomF32(), randomF32(), randomF32());
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

pub inline fn randomInUnitDisk() zm.Vec {
    while (true) {
        const p = zm.f32x4(randomF32M(-1, 1), randomF32M(-1, 1), 0, 0);
        if (zm.lengthSq3(p)[0] < 1.0) return p;
    }
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

pub fn nearZero(e: zm.Vec) bool {
    const s = 1e-8;
    return (@abs(e[0]) < s) and (@abs(e[1]) < s) and (@abs(e[2]) < s);
}

pub inline fn reflect(v: zm.Vec, n: zm.Vec) zm.Vec {
    return v - zm.f32x4s(2 * zm.dot3(v, n)[0]) * n;
}

pub inline fn refract(uv: zm.Vec, n: zm.Vec, etai_over_etat: f32) zm.Vec {
    const cos_theta = @min(zm.dot3(-uv, n)[0], 1.0);
    const r_out_perp = zm.f32x4s(etai_over_etat) * (uv + zm.f32x4s(cos_theta) * n);
    const r_out_parallel = zm.f32x4s(-@sqrt(@abs(1.0 - zm.lengthSq3(r_out_perp)[0]))) * n;
    return r_out_perp + r_out_parallel;
}
