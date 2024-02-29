const std = @import("std");

const spall = @import("spall");
const zigimg = @import("zigimg");
const color = zigimg.color;
const zm = @import("zmath");

const Camera = @import("camera.zig");
pub const hittable = @import("hittable.zig");
const Ray = @import("ray.zig");

const log = std.log.scoped(.rayray);

pub const Raytracer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    camera: Camera,
    world: hittable.HittableList,

    pub fn init(allocator: std.mem.Allocator, world: hittable.HittableList) !Self {
        return .{
            .allocator = allocator,
            .camera = try Camera.init(allocator, 400, 16.0 / 9.0),
            .world = world,
        };
    }

    pub fn deinit(self: *Self) void {
        self.camera.deinit();
        self.world.deinit();
    }

    // TODO: Render in cubes not in rows
    pub fn render(self: *Self) !zigimg.Image {
        const s = spall.trace(@src(), "Render", .{});
        defer s.end();

        const rows: usize = try std.Thread.getCpuCount() - 1;
        const row_height = @divTrunc(self.camera.image_height, rows);
        const num_threads = blk: {
            if (self.camera.image_height % rows == 0) {
                break :blk rows;
            }
            break :blk rows + 1;
        };

        log.debug("rows: {}, row_height: {}, num_threads: {}", .{ rows, row_height, num_threads });

        var threads = try self.allocator.alloc(TaskTracker, num_threads);
        defer self.allocator.free(threads);

        const finished_threads = try self.allocator.alloc(bool, num_threads);

        for (0..num_threads) |row| {
            const t = try std.Thread.spawn(.{}, render_thread, .{ &self.camera, &self.world, row, row_height, &threads[row].done });
            threads[row].thread = t;
        }

        const stderr = std.io.getStdErr();
        defer stderr.close();

        var progress = std.Progress{
            .terminal = stderr,
            .supports_ansi_escape_codes = true,
        };
        var node = progress.start("Rendering Completed", num_threads);
        node.activate();

        while (true) {
            var done = true;
            node.activate();

            for (0..num_threads) |id| {
                if (threads[id].done and !threads[id].marked_as_done) {
                    threads[id].thread.join();
                    threads[id].marked_as_done = true;
                    finished_threads[id] = true;
                    node.completeOne();
                } else if (!threads[id].done) {
                    done = false;
                }
            }

            if (done) break;
        }

        return self.camera.image;
    }

    fn render_thread(cam: *Camera, world: *hittable.HittableList, row: usize, height: usize, done: *bool) void {
        spall.init_thread();
        defer spall.deinit_thread();

        log.debug("Started Render Thread {}", .{row});

        const s = spall.trace(@src(), "Render Thread {}", .{row});
        defer s.end();

        for (0..height) |ij| {
            const j = ij + height * row;
            if (j >= cam.image_height) break;

            for (0..cam.image_width) |i| {
                const pixel_center = cam.pixel00_loc + (zm.f32x4s(@as(f32, @floatFromInt(i))) * cam.pixel_delta_u) + (zm.f32x4s(@as(f32, @floatFromInt(j))) * cam.pixel_delta_v);
                const ray_direction = pixel_center - cam.camera_center;
                var ray = Ray.init(cam.camera_center, ray_direction);
                const col = vecToRgba(ray.color(world));

                cam.setPixel(i, j, col) catch break;
            }
        }

        done.* = true;

        // log.debug("Render Thread {} is done", .{row});
    }
};

const TaskTracker = struct {
    thread: std.Thread,
    done: bool = false,
    marked_as_done: bool = false,
};

fn vecToRgba(v: zm.Vec) color.Rgba32 {
    const r: u8 = @intFromFloat(255.999 * v[0]);
    const g: u8 = @intFromFloat(255.999 * v[1]);
    const b: u8 = @intFromFloat(255.999 * v[2]);
    const a: u8 = @intFromFloat(255.999 * v[3]);

    return color.Rgba32.initRgba(r, g, b, a);
}
