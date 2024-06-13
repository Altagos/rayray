const std = @import("std");

pub const zmath = @import("zmath");

// const spall = @import("spall");
const zigimg = @import("zigimg");
const color = zigimg.color;

pub const BVH = @import("BVH.zig");
pub const Camera = @import("Camera.zig");
pub const hittable = @import("hittable.zig");
pub const interval = @import("interval.zig");
const IntervalUsize = interval.IntervalUsize;
pub const material = @import("material.zig");
pub const tracer = @import("tracer.zig");
pub const util = @import("util.zig");

const log = std.log.scoped(.rayray);

pub const TaskTracker = struct {
    marked_as_done: bool = false,
    done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    thread_id: std.Thread.Id = 0,
};

pub const Raytracer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    thread_pool: *std.Thread.Pool,

    camera: Camera,
    world: BVH,

    pub fn init(allocator: std.mem.Allocator, world: hittable.HittableList, camera_opts: Camera.Options) !Self {
        var thread_pool = try allocator.create(std.Thread.Pool);
        try thread_pool.init(.{ .allocator = allocator });

        return .{
            .allocator = allocator,
            .thread_pool = thread_pool,
            .camera = try Camera.init(allocator, camera_opts),
            .world = try BVH.init(allocator, world, 100),
        };
    }

    pub fn deinit(self: *Self) void {
        self.camera.deinit();
        self.world.deinit();

        self.thread_pool.deinit();
        self.allocator.destroy(self.thread_pool);
    }

    pub fn render(self: *Self) !zigimg.Image {
        // const s = spall.trace(@src(), "Render", .{});
        // defer s.end();

        const chunk_height: usize = 25;
        const chunk_width: usize = 25;

        var rows: usize = @divTrunc(self.camera.image_height, chunk_height);
        if (self.camera.image_height % rows != 0) {
            rows += 1;
        }

        var cols: usize = @divTrunc(self.camera.image_width, chunk_width);
        if (self.camera.image_width % cols != 0) {
            cols += 1;
        }

        const num_chunks = cols * rows;

        log.debug("rows: {}, cols: {}, chunk_height: {}, chunk_width: {}, num_chunks: {}, num_threads: {}", .{
            rows,
            cols,
            chunk_height,
            chunk_width,
            num_chunks,
            self.thread_pool.threads.len,
        });

        const tasks = try self.allocator.alloc(TaskTracker, num_chunks);
        defer self.allocator.free(tasks);

        for (tasks, 0..) |*t, id| {
            const row: usize = @divTrunc(id, cols) * chunk_height;
            const col: usize = (id - cols * @divTrunc(id, cols)) * chunk_width;

            const c_height = IntervalUsize{ .min = row, .max = row + chunk_height };
            const c_width = IntervalUsize{ .min = col, .max = col + chunk_width + 1 };

            const ctx = tracer.Context{
                .cam = &self.camera,
                .world = &self.world,
                .height = c_height,
                .width = c_width,
            };

            try self.thread_pool.spawn(
                renderThread,
                .{ ctx, t, id },
            );
        }

        // const stderr = std.io.getStdErr();

        // var progress = std.Progress{
        //     .terminal = stderr,
        //     .supports_ansi_escape_codes = true,
        // };
        // var node = progress.start("Rendered Chunks", num_chunks);
        // node.setCompletedItems(0);
        // node.context.refresh();

        const num_threads = try std.Thread.getCpuCount();
        var thread_to_idx = std.ArrayList(std.Thread.Id).init(self.allocator);
        defer thread_to_idx.deinit();

        var root_node = std.Progress.start(.{
            .root_name = "Ray Tracer",
            .estimated_total_items = num_threads,
        });
        var nodes = std.ArrayList(std.Progress.Node).init(self.allocator);
        defer nodes.deinit();

        for (0..num_threads) |_| {
            try nodes.append(root_node.start("Chunks Rendered", num_chunks / num_threads));
        }

        var completed_chunks: u64 = 0;
        var i: usize = 0;
        while (true) {
            var done = true;

            for (tasks) |*t| {
                const task_done = t.done.load(.acquire);

                if (task_done and !t.marked_as_done) {
                    t.marked_as_done = true;

                    const idx = blk: {
                        for (thread_to_idx.items, 0..) |value, idx| {
                            if (value == t.thread_id) break :blk idx;
                        }
                        try thread_to_idx.append(t.thread_id);
                        const idx = i;
                        i += 1;
                        break :blk idx;
                    };
                    nodes.items[idx].completeOne();

                    completed_chunks += 1;
                    if (completed_chunks % self.thread_pool.threads.len == 0) try self.camera.image.writeToFilePath("./out/out.png", .{ .png = .{} });
                } else if (!task_done) {
                    done = false;
                }
            }

            if (done or !self.thread_pool.is_running) break;
        }

        // node.end();

        return self.camera.image;
    }
};

pub fn renderThread(ctx: tracer.Context, task: *TaskTracker, id: usize) void {
    defer task.done.store(true, .release);
    task.thread_id = std.Thread.getCurrentId();
    _ = id;
    tracer.trace(ctx);
}
