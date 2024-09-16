const std = @import("std");
const build_options = @import("build-options");

pub const zmath = @import("zmath");

const zigimg = @import("zigimg");
const color = zigimg.color;

pub const BVH = @import("BVH.zig");
pub const Camera = @import("Camera.zig");
pub const hittable = @import("hittable.zig");
pub const interval = @import("interval.zig");
const IntervalUsize = interval.IntervalUsize;
pub const material = @import("material.zig");
pub const texture = @import("texture.zig");
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
    world: hittable.HittableList,

    pub fn init(allocator: std.mem.Allocator, world: hittable.HittableList, camera_opts: Camera.Options) !Self {
        var thread_pool = try allocator.create(std.Thread.Pool);
        try thread_pool.init(.{ .allocator = allocator });

        return .{
            .allocator = allocator,
            .thread_pool = thread_pool,
            .camera = try Camera.init(allocator, camera_opts),
            .world = world,
        };
    }

    pub fn deinit(self: *Self) void {
        self.camera.deinit();
        self.world.deinit();

        self.thread_pool.deinit();
        self.allocator.destroy(self.thread_pool);
    }

    pub fn render(self: *Self) !zigimg.Image {
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

        const num_threads = blk: {
            const count = try std.Thread.getCpuCount();
            if (count > 1) {
                break :blk count;
            } else break :blk 1;
        };

        log.debug("rows: {}, cols: {}, chunk_height: {}, chunk_width: {}, num_chunks: {}, num_threads: {}", .{
            rows,
            cols,
            chunk_height,
            chunk_width,
            num_chunks,
            num_threads,
        });

        var root_node = std.Progress.start(.{
            .root_name = "Ray Tracer",
            .estimated_total_items = 3,
        });

        var bvh_node = root_node.start("Createing BVH", 0);

        var world_bvh = try BVH.init(self.allocator, self.world, build_options.max_depth);

        bvh_node.end();
        root_node.setCompletedItems(0);

        var task_node = root_node.start("Creating render tasks", 0);

        const tasks = try self.allocator.alloc(TaskTracker, num_chunks);
        defer self.allocator.free(tasks);

        for (tasks, 0..) |*t, id| {
            const row: usize = @divTrunc(id, cols) * chunk_height;
            const col: usize = (id - cols * @divTrunc(id, cols)) * chunk_width;

            const c_height = IntervalUsize{ .min = row, .max = row + chunk_height };
            const c_width = IntervalUsize{ .min = col, .max = col + chunk_width + 1 };

            const ctx = tracer.Context{
                .cam = &self.camera,
                .world = &world_bvh,
                .height = c_height,
                .width = c_width,
            };

            try self.thread_pool.spawn(
                renderThread,
                .{ ctx, t },
            );
        }

        task_node.end();
        root_node.setCompletedItems(1);

        var render_node = root_node.start("Rendering", num_chunks);

        var thread_to_idx = std.ArrayList(std.Thread.Id).init(self.allocator);
        defer thread_to_idx.deinit();

        var nodes = std.ArrayList(std.Progress.Node).init(self.allocator);
        defer nodes.deinit();

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

                        const node_msg = try std.fmt.allocPrint(self.allocator, "Render Thread #{}", .{i});
                        defer self.allocator.free(node_msg);
                        try nodes.append(render_node.start(node_msg, num_chunks / num_threads));
                        root_node.setCompletedItems(1);

                        i += 1;
                        break :blk i;
                    };
                    nodes.items[idx].completeOne();

                    completed_chunks += 1;
                    render_node.setCompletedItems(completed_chunks);
                    // if (completed_chunks % self.thread_pool.threads.len == 0) try self.camera.image.writeToFilePath("./out/out.png", .{ .png = .{} });
                } else if (!task_done) {
                    done = false;
                }
            }

            if (done or !self.thread_pool.is_running) break;
        }

        render_node.end();
        root_node.setCompletedItems(3);

        return self.camera.image;
    }
};

pub fn renderThread(ctx: tracer.Context, task: *TaskTracker) void {
    defer task.done.store(true, .release);
    task.thread_id = std.Thread.getCurrentId();
    tracer.trace(ctx);
}
