const std = @import("std");

const spall = @import("spall");
const zigimg = @import("zigimg");
const zm = @import("zmath");

const Camera = @import("camera.zig");
const hittable = @import("hittable.zig");
const material = @import("material.zig");
const Ray = @import("ray.zig");
const util = @import("util.zig");

const interval = @import("a").interval;
const IntervalUsize = interval.IntervalUsize;
const IntervalF32 = interval.IntervalF32;

const log = std.log.scoped(.renderer);

pub const Context = struct {
    cam: *Camera,
    world: *hittable.HittableList,
};

pub fn rayColor(r: *Ray, world: *hittable.HittableList, depth: usize) zm.Vec {
    if (depth <= 0) return zm.f32x4(0, 0, 0, 1.0);

    if (world.hit(r, IntervalF32.init(0.001, std.math.inf(f32)))) |rec| {
        var attenuation = zm.f32x4s(1.0);
        if (rec.mat.scatter(r, @constCast(&rec), &attenuation)) |new_r| {
            return attenuation * rayColor(@constCast(&new_r), world, depth - 1);
        }

        return zm.f32x4(0, 0, 0, 1.0);
    }

    const unit_direction = zm.normalize3(r.dir);
    const a = 0.5 * (unit_direction[1] + 1.0);
    return zm.f32x4s(1.0 - a) * zm.f32x4s(1.0) + zm.f32x4s(a) * zm.f32x4(0.5, 0.7, 1.0, 1.0);
}

pub fn run(ctx: Context, height: IntervalUsize, width: IntervalUsize) void {
    var height_iter = height.iter();
    while (height_iter.nextInc()) |j| {
        if (j >= ctx.cam.image_height) break;

        var width_iter = width.iter();
        while (width_iter.nextExc()) |i| {
            var col = zm.f32x4(0.0, 0.0, 0.0, 1.0);
            for (0..ctx.cam.samples_per_pixel) |_| {
                var ray = ctx.cam.getRay(i, j);
                col += rayColor(&ray, ctx.world, ctx.cam.max_depth);
            }

            ctx.cam.setPixel(i, j, vecToRgba(col, ctx.cam.samples_per_pixel)) catch break;
        }
    }
}

fn vecToRgba(v: zm.Vec, samples_per_pixel: usize) zigimg.color.Rgba32 {
    const scale: f32 = 1.0 / @as(f32, @floatFromInt(samples_per_pixel));
    const intensity = IntervalF32.init(0.0, 0.999);

    const r_scaled = linearToGamma(v[0] * scale);
    const g_scaled = linearToGamma(v[1] * scale);
    const b_scaled = linearToGamma(v[2] * scale);
    const a_scaled = linearToGamma(v[3] * scale);

    const r: u8 = @intFromFloat(256 * intensity.clamp(r_scaled));
    const g: u8 = @intFromFloat(256 * intensity.clamp(g_scaled));
    const b: u8 = @intFromFloat(256 * intensity.clamp(b_scaled));
    const a: u8 = @intFromFloat(256 * intensity.clamp(a_scaled));

    return zigimg.color.Rgba32.initRgba(r, g, b, a);
}

inline fn linearToGamma(linear_component: f32) f32 {
    return @sqrt(linear_component);
}
