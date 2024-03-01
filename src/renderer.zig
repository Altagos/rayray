const std = @import("std");

const spall = @import("spall");
const zigimg = @import("zigimg");
const zm = @import("zmath");

const Camera = @import("camera.zig");
const hittable = @import("hittable.zig");
const Ray = @import("ray.zig");
const util = @import("util.zig");

const interval = @import("interval.zig");
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
        r.orig = rec.p;
        r.dir = util.randomOnHemisphere(rec.normal);
        return zm.f32x4(0.5, 0.5, 0.5, 1.0) * rayColor(r, world, depth - 1);
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

pub fn renderThread(ctx: Context, done: *std.atomic.Value(bool), row: usize, row_height: usize) void {
    spall.init_thread();
    defer spall.deinit_thread();

    const height = IntervalUsize{ .min = row_height * row, .max = row_height * row + row_height };
    const width = IntervalUsize{ .min = 0, .max = ctx.cam.image_width };

    log.debug("Started Render Thread {}", .{row});

    const s = spall.trace(@src(), "Render Thread {}", .{row});
    defer s.end();

    run(ctx, height, width);

    done.store(true, .Release);
}

fn vecToRgba(v: zm.Vec, samples_per_pixel: usize) zigimg.color.Rgba32 {
    const scale: f32 = 1.0 / @as(f32, @floatFromInt(samples_per_pixel));
    const intensity = IntervalF32.init(0.0, 0.999);

    const r_scaled = v[0] * scale;
    const g_scaled = v[1] * scale;
    const b_scaled = v[2] * scale;
    const a_scaled = v[3] * scale;

    const r: u8 = @intFromFloat(256 * intensity.clamp(r_scaled));
    const g: u8 = @intFromFloat(256 * intensity.clamp(g_scaled));
    const b: u8 = @intFromFloat(256 * intensity.clamp(b_scaled));
    const a: u8 = @intFromFloat(256 * intensity.clamp(a_scaled));

    return zigimg.color.Rgba32.initRgba(r, g, b, a);
}
