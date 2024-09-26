const std = @import("std");
const random = std.crypto.random;

const zigimg = @import("zigimg");
const color = zigimg.color;
const zm = @import("zmath");

pub const Ray = @import("Ray.zig");
const util = @import("util.zig");

const log = std.log.scoped(.camera);

const Camera = @This();

pub const Options = struct {
    image_width: usize,
    aspect_ratio: f32,
    samples_per_pixel: usize,
    max_depth: usize,

    vfov: f32 = 90,
    look_from: zm.Vec = zm.f32x4s(0),
    look_at: zm.Vec = zm.f32x4(0, 0, -1, 0),
    vup: zm.Vec = zm.f32x4(0, 1, 0, 0),

    defocus_angle: f32 = 0,
    focus_dist: f32 = 10,
};

image_height: usize,
image_width: usize,
aspect_ratio: f32,

samples_per_pixel: usize,
samples_per_pixel_v: zm.Vec,
max_depth: usize,

vfov: f32,
look_from: zm.Vec,
look_at: zm.Vec,
vup: zm.Vec,

defocus_angle: f32,
focus_dist: f32,

// focal_lenght: f32,
viewport_height: f32,
viewport_width: f32,
center: zm.Vec,

viewport_u: zm.Vec,
viewport_v: zm.Vec,
pixel_delta_u: zm.Vec,
pixel_delta_v: zm.Vec,
u: zm.Vec,
v: zm.Vec,
w: zm.Vec,
defocus_disk_u: zm.Vec,
defocus_disk_v: zm.Vec,

viewport_upper_left: zm.Vec,
pixel00_loc: zm.Vec,

image: zigimg.Image,

pub fn init(allocator: std.mem.Allocator, opts: Options) !Camera {
    const image_width = opts.image_width;
    const aspect_ratio = opts.aspect_ratio;
    const image_height = @as(usize, @intFromFloat(@as(f32, @floatFromInt(image_width)) / aspect_ratio));
    if (image_height < 1) return error.ImageWidthLessThanOne;

    const vfov = opts.vfov;
    const look_from = opts.look_from;
    const look_at = opts.look_at;
    const vup = opts.vup;
    const center = look_from;

    const defocus_angle = opts.defocus_angle;
    const focus_dist = opts.focus_dist;

    // const focal_lenght: f32 = zm.length3(look_from - look_at)[0];
    const theta = util.degreesToRadians(opts.vfov);
    const h = @tan(theta / 2);
    const viewport_height: f32 = 2 * h * focus_dist;
    const viewport_width = viewport_height * (@as(f32, @floatFromInt(image_width)) / @as(f32, @floatFromInt(image_height)));

    const w = zm.normalize3(look_from - look_at);
    const u = zm.normalize3(zm.cross3(vup, w));
    const v = zm.cross3(w, u);

    // Calculate the vectors across the horizontal and down the vertical viewport edges.
    const viewport_u = zm.f32x4s(viewport_width) * u;
    const viewport_v = zm.f32x4s(viewport_height) * -v;

    // Calculate the horizontal and vertical delta vectors from pixel to pixel.
    const pixel_delta_u = viewport_u / zm.f32x4s(@as(f32, @floatFromInt(image_width)));
    const pixel_delta_v = viewport_v / zm.f32x4s(@as(f32, @floatFromInt(image_height)));

    // Calculate the location of the upper left pixel.
    const viewport_upper_left = center - zm.f32x4s(focus_dist) * w - viewport_u / zm.f32x4s(2.0) - viewport_v / zm.f32x4s(2.0);
    const pixel00_loc = viewport_upper_left + zm.f32x4s(0.5) * (pixel_delta_u + pixel_delta_v);

    // Calculate the camera defocus disk basis vectors.
    const defocus_radius = focus_dist * @tan(util.degreesToRadians(defocus_angle / 2));
    const defocus_disk_u = u * zm.f32x4s(defocus_radius);
    const defocus_disk_v = v * zm.f32x4s(defocus_radius);

    // log.debug("image_width: {}, image_height: {}, aspect_ratio: {d:.2}, focal_lenght: {d:.1}", .{
    //     image_width,
    //     image_height,
    //     aspect_ratio,
    //     focal_lenght,
    // });

    return Camera{
        .image_width = image_width,
        .image_height = image_height,
        .aspect_ratio = aspect_ratio,

        .samples_per_pixel = opts.samples_per_pixel,
        .samples_per_pixel_v = zm.f32x4s(@as(f32, @floatFromInt(opts.samples_per_pixel))),
        .max_depth = opts.max_depth,

        .vfov = vfov,
        .look_from = look_from,
        .look_at = look_at,
        .vup = vup,

        .defocus_angle = opts.defocus_angle,
        .focus_dist = opts.focus_dist,

        // .focal_lenght = opts.focal_lenght,
        .viewport_height = viewport_height,
        .viewport_width = viewport_width,
        .center = center,

        .viewport_u = viewport_u,
        .viewport_v = viewport_v,
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,
        .u = u,
        .v = v,
        .w = w,
        .defocus_disk_u = defocus_disk_u,
        .defocus_disk_v = defocus_disk_v,

        .viewport_upper_left = viewport_upper_left,
        .pixel00_loc = pixel00_loc,

        .image = try zigimg.Image.create(allocator, image_width, image_height, zigimg.PixelFormat.rgba32),
    };
}

pub fn deinit(self: *Camera) void {
    self.image.deinit();
}

pub fn getRay(self: *const Camera, i: usize, j: usize) Ray {
    const offset = sampleSquare();
    const pixel_sample = self.pixel00_loc +
        (zm.f32x4s(@as(f32, @floatFromInt(i)) + offset[0]) * self.pixel_delta_u) +
        (zm.f32x4s(@as(f32, @floatFromInt(j)) + offset[1]) * self.pixel_delta_v);

    const ray_orig = if (self.defocus_angle <= 0) self.center else self.defocusDiskSample();
    const ray_direction = pixel_sample - ray_orig;
    const ray_time = util.randomF32();

    return Ray.initT(ray_orig, ray_direction, ray_time);
}

fn sampleSquare() zm.Vec {
    return zm.f32x4(util.randomF32() - 0.5, util.randomF32() - 0.5, 0, 0);
}

fn defocusDiskSample(self: *const Camera) zm.Vec {
    const p = util.randomInUnitDisk();
    return self.center + (zm.f32x4s(p[0]) * self.defocus_disk_u) + (zm.f32x4s(p[1]) * self.defocus_disk_v);
}

pub fn setPixel(self: *Camera, x: usize, y: usize, c: color.Rgba32) !void {
    if (x >= self.image_width or y >= self.image_height) return error.OutOfBounds;
    const i = x + self.image_width * y;
    self.image.pixels.rgba32[i] = c;
}

fn pixelSamplesSq(self: *const Camera) zm.Vec {
    const px = zm.f32x4s(-0.5 + random.float(f32));
    const py = zm.f32x4s(-0.5 + random.float(f32));
    return (px * self.pixel_delta_u) + (py * self.pixel_delta_v);
}
