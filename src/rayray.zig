const std = @import("std");

const spall = @import("spall");
const zigimg = @import("zigimg");
const color = zigimg.color;

pub const Camera = @import("camera.zig");
pub const hittable = @import("hittable.zig");
pub const material = @import("material.zig");
pub const renderer = @import("renderer.zig");

const IntervalUsize = @import("a").interval.IntervalUsize;

const log = std.log.scoped(.rayray);

const ThreadTracker = struct {
    thread: std.Thread,
    done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    marked_as_done: bool = false,
};

pub const Raytracer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    camera: Camera,
    world: hittable.HittableList,

    pub fn init(allocator: std.mem.Allocator, world: hittable.HittableList, camera_opts: Camera.Options) !Self {
        return .{
            .allocator = allocator,
            .camera = try Camera.init(allocator, camera_opts),
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

        var threads = try self.allocator.alloc(ThreadTracker, num_threads);
        defer self.allocator.free(threads);

        const finished_threads = try self.allocator.alloc(bool, num_threads);

        for (0..num_threads) |row| {
            const ctx = renderer.Context{ .cam = &self.camera, .world = &self.world };
            const t = try std.Thread.spawn(.{}, renderThread, .{ ctx, &threads[row].done, row, row_height });
            threads[row].thread = t;
        }

        const stderr = std.io.getStdErr();

        var progress = std.Progress{
            .terminal = stderr,
            .supports_ansi_escape_codes = true,
        };
        var node = progress.start("Rendering", num_threads);
        node.activate();

        while (true) {
            var done = true;

            for (0..num_threads) |id| {
                if (threads[id].done.load(.Acquire) and !threads[id].marked_as_done) {
                    threads[id].thread.join();
                    threads[id].marked_as_done = true;
                    finished_threads[id] = true;
                    node.completeOne();
                } else if (!threads[id].done.load(.Acquire)) {
                    done = false;
                }
            }

            node.context.refresh();

            if (done) break;
        }

        node.end();

        return self.camera.image;
    }
};

pub fn renderThread(ctx: renderer.Context, done: *std.atomic.Value(bool), row: usize, row_height: usize) void {
    spall.init_thread();
    defer spall.deinit_thread();

    const height = IntervalUsize{ .min = row_height * row, .max = row_height * row + row_height };
    const width = IntervalUsize{ .min = 0, .max = ctx.cam.image_width };

    // log.debug("Started Render Thread {}", .{row});

    const s = spall.trace(@src(), "Render Thread {}", .{row});
    defer s.end();

    renderer.run(ctx, height, width);

    done.store(true, .Release);
}
