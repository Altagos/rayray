const std = @import("std");

const spall = @import("spall");
const zigimg = @import("zigimg");
const zm = @import("zmath");

const BVH = @import("BVH.zig");
const Camera = @import("Camera.zig");
const hittable = @import("hittable.zig");
const material = @import("material.zig");
const Ray = @import("Ray.zig");
const util = @import("util.zig");

const interval = @import("interval.zig");
const IntervalUsize = interval.IntervalUsize;
const IntervalF32 = interval.IntervalF32;

const log = std.log.scoped(.tracer);

pub const Context = struct {
    pixels: []zm.Vec,
    cam: *const Camera,
    world: *const BVH,
    height: IntervalUsize,
    width: IntervalUsize,
};

const white = zm.f32x4s(1.0);
const black = zm.f32x4(0, 0, 0, 1.0);

pub fn rayColor(r: *Ray, world: *const BVH, depth: usize) zm.Vec {
    @setFloatMode(.optimized);
    if (depth == 0) return backgroundColor(r);

    if (world.hit(r, .{ .min = 0.001, .max = std.math.inf(f32) })) |rec| {
        var attenuation = zm.f32x4s(1.0);
        if (rec.mat.scatter(r, &rec, &attenuation)) |new_r| {
            return attenuation * rayColor(@constCast(&new_r), world, depth - 1);
        }
    }

    return backgroundColor(r);
}

fn backgroundColor(r: *Ray) zm.Vec {
    const unit_direction = zm.normalize3(r.dir);
    const a = 0.5 * (unit_direction[1] + 1.0);
    return zm.f32x4s(1.0 - a) * zm.f32x4s(1.0) + zm.f32x4s(a) * zm.f32x4(0.5, 0.7, 1.0, 1.0);
}

pub fn trace(ctx: *Context) void {
    var height_iter = ctx.height.iter();
    while (height_iter.nextInc()) |j| {
        if (j >= ctx.cam.image_height) break;

        var width_iter = ctx.width.iter();
        while (width_iter.nextExc()) |i| inner: {
            var col = zm.f32x4(0.0, 0.0, 0.0, 1.0);

            for (0..ctx.cam.samples_per_pixel) |_| {
                var ray = ctx.cam.getRay(i, j);
                col += rayColor(&ray, ctx.world, ctx.cam.max_depth);
            }

            setPixel(ctx.pixels, ctx.cam, i, j, col) catch {
                log.err("Trying to set a pixel out of bounds ({}, {})", .{ i, j });
                break :inner;
            };
        }
    }
}

const zero = zm.f32x4s(0.0);
const nearly_one = zm.f32x4s(0.999);
const v256 = zm.f32x4s(256);

inline fn vecToRgba(v: zm.Vec, samples_per_pixel: zm.Vec) zigimg.color.Rgba32 {
    const rgba = zm.clampFast(
        @sqrt(v / samples_per_pixel),
        zero,
        nearly_one,
    ) * v256; // linear to gamma

    return zigimg.color.Rgba32.initRgba(
        @intFromFloat(rgba[0]),
        @intFromFloat(rgba[1]),
        @intFromFloat(rgba[2]),
        @intFromFloat(rgba[3]),
    );
}

pub fn setPixel(pixels: []zm.Vec, cam: *const Camera, x: usize, y: usize, c: zm.Vec) !void {
    if (x >= cam.image_width or y >= cam.image_height) return error.OutOfBounds;
    const i = x + cam.image_width * y;
    pixels[i] = c;
    // try cam.setPixel(x, y, vecToRgba(c, cam.samples_per_pixel_v));
}
