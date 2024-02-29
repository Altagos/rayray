const std = @import("std");

const spall = @import("spall");
const zigimg = @import("zigimg");
const color = zigimg.color;
const zm = @import("zmath");

const Camera = @import("camera.zig");
const Ray = @import("ray.zig");

const log = std.log.scoped(.rayray);

pub const Raytracer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    camera: Camera,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
            .camera = try Camera.init(allocator, 400, 16.0 / 9.0),
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
        const row_height = @divTrunc(self.camera.image_height, rows);
        const num_threads = blk: {
            if (self.camera.image_height % rows == 0) {
                break :blk rows;
            }
            break :blk rows + 1;
        };

        log.debug("rows: {}, row_height: {}, num_threads: {}", .{ rows, row_height, num_threads });

        const threads = try self.allocator.alloc(std.Thread, num_threads);
        defer self.allocator.free(threads);

        for (0..num_threads) |row| {
            const t = try std.Thread.spawn(.{}, render_thread, .{ &self.camera, row, row_height });
            threads[row] = t;
        }

        for (threads) |t| {
            t.join();
        }

        return self.camera.image;
    }

    fn render_thread(cam: *Camera, row: usize, height: usize) void {
        spall.init_thread();
        defer spall.deinit_thread();

        const s = spall.trace(@src(), "Render Thread {}", .{row});
        defer s.end();

        for (0..height) |ij| {
            const j = ij + height * row;
            if (j >= cam.image_height) break;

            for (0..cam.image_width) |i| {
                const pixel_center = cam.pixel00_loc + (zm.f32x4s(@as(f32, @floatFromInt(i))) * cam.pixel_delta_u) + (zm.f32x4s(@as(f32, @floatFromInt(j))) * cam.pixel_delta_v);
                const ray_direction = pixel_center - cam.camera_center;
                var ray = Ray.init(cam.camera_center, ray_direction);
                const col = vecToRgba(ray.color());

                cam.setPixel(i, j, col) catch break;
            }
        }
    }
};

fn vecToRgba(v: zm.Vec) color.Rgba32 {
    const r: u8 = @intFromFloat(255.999 * v[0]);
    const g: u8 = @intFromFloat(255.999 * v[1]);
    const b: u8 = @intFromFloat(255.999 * v[2]);
    const a: u8 = @intFromFloat(255.999 * v[3]);

    return color.Rgba32.initRgba(r, g, b, a);
}
