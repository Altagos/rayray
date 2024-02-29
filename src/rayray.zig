const std = @import("std");

const spall = @import("spall");
const zigimg = @import("zigimg");
const color = zigimg.color;

const log = std.log.scoped(.rayray);

pub const Raytracer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    camera: Camera,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .camera = try Camera.init(allocator, 256 * 10, 256 * 10),
        };
    }

    pub fn deinit(self: *const Self) void {
        _ = self;
    }

    // TODO: Render in cubes not in rows
    pub fn render(self: *Self) !zigimg.Image {
        const s = spall.trace(@src(), "Render", .{});
        defer s.end();

        const rows: usize = try std.Thread.getCpuCount();
        const row_height = @divTrunc(self.camera.height, rows);
        const num_threads = blk: {
            if (self.camera.height % rows == 0) {
                break :blk rows;
            }
            break :blk rows + 1;
        };

        log.debug("rows: {}, row_height: {}, num_threads: {}", .{ rows, row_height, num_threads });

        const threads = try self.allocator.alloc(std.Thread, num_threads);
        defer self.allocator.free(threads);

        for (0..num_threads) |row| {
            const t = try std.Thread.spawn(.{}, r, .{ &self.camera, row, row_height });
            threads[row] = t;
        }

        for (threads) |t| {
            t.join();
        }

        return self.camera.image;
    }

    fn r(cam: *Camera, row: usize, height: usize) void {
        spall.init_thread();
        defer spall.deinit_thread();

        const s = spall.trace(@src(), "Render Thread {}", .{row});
        defer s.end();

        for (0..height) |iy| {
            const y = iy + height * row;
            if (y >= cam.height) break;

            for (0..cam.width) |x| {
                const col = blk: {
                    if (iy <= height - 5) {
                        @setRuntimeSafety(false);
                        break :blk color.Rgba32.initRgba(
                            @intCast(x),
                            @intCast(y),
                            0,
                            255,
                        );
                    }
                    break :blk color.Rgba32.initRgba(0, 0, 255, 255);
                };

                cam.setPixel(x, y, col) catch break;
            }
        }
    }
};

pub const Camera = struct {
    width: usize,
    height: usize,
    image: zigimg.Image,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Camera {
        const img = try zigimg.Image.create(allocator, width, height, zigimg.PixelFormat.rgba32);

        return Camera{
            .width = width,
            .height = height,
            .image = img,
        };
    }

    pub fn setPixel(self: *Camera, x: usize, y: usize, c: color.Rgba32) !void {
        if (x >= self.width or y >= self.height) return error.OutOfBounds;
        const i = x + self.width * y;
        self.image.pixels.rgba32[i] = c;
    }
};
