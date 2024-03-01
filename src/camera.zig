const std = @import("std");

const zigimg = @import("zigimg");
const color = zigimg.color;
const zm = @import("zmath");

const log = std.log.scoped(.camera);

const Camera = @This();

pub const Options = struct {
    image_width: usize,
    aspect_ratio: f32,
};

image_height: usize,
image_width: usize,
aspect_ratio: f32,

focal_lenght: f32,
viewport_height: f32,
viewport_width: f32,
camera_center: zm.Vec,

viewport_u: zm.Vec,
viewport_v: zm.Vec,
pixel_delta_u: zm.Vec,
pixel_delta_v: zm.Vec,

viewport_upper_left: zm.Vec,
pixel00_loc: zm.Vec,

image: zigimg.Image,

pub fn init(allocator: std.mem.Allocator, opts: Options) !Camera {
    const image_width = opts.image_width;
    const aspect_ratio = opts.aspect_ratio;
    const image_height = @as(usize, @intFromFloat(@as(f32, @floatFromInt(image_width)) / aspect_ratio));
    if (image_height < 1) return error.ImageWidthLessThanOne;

    const focal_lenght: f32 = 1.0;
    const viewport_height: f32 = 2.0;
    const viewport_width = viewport_height * (@as(f32, @floatFromInt(image_width)) / @as(f32, @floatFromInt(image_height)));
    const camera_center = zm.f32x4s(0.0);

    // Calculate the vectors across the horizontal and down the vertical viewport edges.
    const viewport_u = zm.f32x4(viewport_width, 0, 0, 0);
    const viewport_v = zm.f32x4(0, -viewport_height, 0, 0);

    // Calculate the horizontal and vertical delta vectors from pixel to pixel.
    const pixel_delta_u = viewport_u / zm.f32x4s(@as(f32, @floatFromInt(image_width)));
    const pixel_delta_v = viewport_v / zm.f32x4s(@as(f32, @floatFromInt(image_height)));

    // Calculate the location of the upper left pixel.
    const viewport_upper_left = camera_center - zm.f32x4(0, 0, focal_lenght, 0) - viewport_u / zm.f32x4s(2.0) - viewport_v / zm.f32x4s(2.0);
    const pixel00_loc = viewport_upper_left + zm.f32x4s(0.5) * (pixel_delta_u + pixel_delta_v);

    log.debug("image_width: {}, image_height: {}, aspect_ratio: {d:.2}, focal_lenght: {d:.1}", .{ image_width, image_height, aspect_ratio, focal_lenght });

    return Camera{
        .image_width = image_width,
        .image_height = image_height,
        .aspect_ratio = aspect_ratio,

        .focal_lenght = focal_lenght,
        .viewport_height = viewport_height,
        .viewport_width = viewport_width,
        .camera_center = camera_center,

        .viewport_u = viewport_u,
        .viewport_v = viewport_v,
        .pixel_delta_u = pixel_delta_u,
        .pixel_delta_v = pixel_delta_v,

        .viewport_upper_left = viewport_upper_left,
        .pixel00_loc = pixel00_loc,

        .image = try zigimg.Image.create(allocator, image_width, image_height, zigimg.PixelFormat.rgba32),
    };
}

pub fn deinit(self: *Camera) void {
    self.image.deinit();
}

pub fn setPixel(self: *Camera, x: usize, y: usize, c: color.Rgba32) !void {
    if (x >= self.image_width or y >= self.image_height) return error.OutOfBounds;
    const i = x + self.image_width * y;
    self.image.pixels.rgba32[i] = c;
}
