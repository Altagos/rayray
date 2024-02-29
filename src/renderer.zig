const std = @import("std");

const spall = @import("spall");
const zigimg = @import("zigimg");
const color = zigimg.color;
const zm = @import("zmath");

pub const Camera = @import("camera.zig");
pub const interval = @import("interval.zig");
pub const IntervalUsize = interval.IntervalUsize;
pub const IntervalF32 = interval.IntervalF32;
pub const hittable = @import("hittable.zig");
pub const Ray = @import("ray.zig");

const log = std.log.scoped(.renderer);

pub const Context = struct {
    cam: *Camera,
    world: *hittable.HittableList,
};

pub fn rayColor(r: *Ray, world: *hittable.HittableList) zm.Vec {
    if (world.hit(r, IntervalF32.init(0, std.math.inf(f32)))) |rec| {
        return zm.f32x4s(0.5) * (rec.normal + zm.f32x4(1, 1, 1, 1));
    }

    const unit_direction = zm.normalize3(r.dir);
    const a = 0.5 * (unit_direction[1] + 1.0);
    return zm.f32x4s(1.0 - a) * zm.f32x4s(1.0) + zm.f32x4s(a) * zm.f32x4(0.5, 0.7, 1.0, 1.0);
}

pub fn run(ctx: Context, height: IntervalUsize, width: IntervalUsize) void {
    var height_iter = height.iter();
    height_iter.upper_boundry = .inclusive;

    while (height_iter.next()) |j| {
        if (j >= ctx.cam.image_height) break;

        var width_iter = width.iter();
        height_iter.upper_boundry = .inclusive;

        while (width_iter.next()) |i| inner: {
            if (i >= ctx.cam.image_width) break :inner;

            const pixel_center = ctx.cam.pixel00_loc + (zm.f32x4s(@as(f32, @floatFromInt(i))) * ctx.cam.pixel_delta_u) + (zm.f32x4s(@as(f32, @floatFromInt(j))) * ctx.cam.pixel_delta_v);
            const ray_direction = pixel_center - ctx.cam.camera_center;
            var ray = Ray.init(ctx.cam.camera_center, ray_direction);
            const col = vecToRgba(rayColor(&ray, ctx.world));

            ctx.cam.setPixel(i, j, col) catch break;
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

fn vecToRgba(v: zm.Vec) color.Rgba32 {
    const r: u8 = @intFromFloat(255.999 * v[0]);
    const g: u8 = @intFromFloat(255.999 * v[1]);
    const b: u8 = @intFromFloat(255.999 * v[2]);
    const a: u8 = @intFromFloat(255.999 * v[3]);

    return color.Rgba32.initRgba(r, g, b, a);
}
