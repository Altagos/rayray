const std = @import("std");
pub const build_options = @import("build-options");

pub const zmath = @import("zmath");

const zigimg = @import("zigimg");
const color = zigimg.color;

pub const BVH = @import("BVH.zig");
pub const Camera = @import("Camera.zig");
pub const hittable = @import("hittable.zig");
pub const interval = @import("interval.zig");
const IntervalUsize = interval.IntervalUsize;
pub const material = @import("material.zig");
pub const Scene = @import("Scene.zig");
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

    scene: Scene,
    cols: usize,
    rows: usize,
    num_chunks: usize,
    num_threads: usize,
    chunks_per_thread: usize,

    const chunk_height: usize = 25;
    const chunk_width: usize = 25;

    pub fn init(allocator: std.mem.Allocator, scene: Scene) !Self {
        var thread_pool = try allocator.create(std.Thread.Pool);
        try thread_pool.init(.{ .allocator = allocator });

        const num_threads = blk: {
            const count = try std.Thread.getCpuCount();
            if (count > 1) {
                break :blk count;
            } else break :blk 1;
        };

        var rows: usize = @divTrunc(scene.camera.image_height, chunk_height);
        if (scene.camera.image_height % rows != 0) {
            rows += 1;
        }

        var cols: usize = @divTrunc(scene.camera.image_width, chunk_width);
        if (scene.camera.image_width % cols != 0) {
            cols += 1;
        }

        const num_chunks = cols * rows;

        log.debug("with: {}, height: {}, rows: {}, cols: {}, chunk_height: {}, chunk_width: {}, num_chunks: {}, num_threads: {}", .{
            scene.camera.image_width,
            scene.camera.image_height,
            rows,
            cols,
            chunk_height,
            chunk_width,
            num_chunks,
            num_threads,
        });

        return .{
            .allocator = allocator,
            .thread_pool = thread_pool,
            .scene = scene,
            .cols = cols,
            .rows = rows,
            .num_chunks = num_chunks,
            .num_threads = num_threads,
            .chunks_per_thread = num_chunks / num_threads,
        };
    }

    pub fn deinit(self: *Self) void {
        self.scene.deinit();
        self.thread_pool.deinit();
        self.allocator.destroy(self.thread_pool);
    }

    pub fn render(self: *Self) !zigimg.Image {
        var root_node = std.Progress.start(.{
            .root_name = "Ray Tracer",
            .estimated_total_items = 4,
        });

        var bvh_node = root_node.start("Createing BVH", 0);

        var world_bvh = try BVH.init(self.allocator, self.scene.world, build_options.max_depth);

        bvh_node.end();
        // root_node.setCompletedItems(0);

        var create_pixels_node = root_node.start("Create pixel array", 0);

        const pixels: []zmath.Vec = try self.allocator.alloc(zmath.Vec, self.scene.camera.image_height * self.scene.camera.image_width);
        defer self.allocator.free(pixels);
        // const l = pixels.ptr;

        create_pixels_node.end();
        // root_node.setCompletedItems(1);

        var task_node = root_node.start("Creating render tasks", 0);

        const tasks: []TaskTracker = try self.allocator.alloc(TaskTracker, self.num_chunks);
        defer self.allocator.free(tasks);

        for (tasks, 0..) |*t, id| {
            // const row: usize = @divTrunc(id, cols) * chunk_height;
            // const col: usize = (id - cols * @divTrunc(id, cols)) * chunk_width;
            const row: usize = (id / self.cols) * chunk_height;
            const col: usize = (id % self.cols) * chunk_width;

            const c_height = IntervalUsize{ .min = row, .max = row + chunk_height };
            const c_width = IntervalUsize{ .min = col, .max = col + chunk_width + 1 };

            const ctx = try self.allocator.create(tracer.Context);

            ctx.* = tracer.Context{
                .pixels = pixels,
                .cam = &self.scene.camera,
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
        // root_node.setCompletedItems(2);

        var render_node = root_node.start("Rendering", self.num_chunks);

        try self.awaitTasks(&render_node, tasks);

        log.info("Rendering done!", .{});

        render_node.end();
        // root_node.setCompletedItems(4);

        var image_node = root_node.start("Creating Image", 0);
        defer image_node.end();

        for (pixels, 0..) |pix, p| {
            const y = p / self.scene.camera.image_width;
            const x = p % self.scene.camera.image_width;
            if (pix[0] < 0 or pix[1] < 0 or pix[2] < 0) {
                // std.log.debug("wrong ({}, {}) {}", .{ x, y, pix });
                try self.scene.camera.setPixel(x, y, zigimg.color.Rgba32.initRgb(255, 0, 0));
                continue;
            }
            self.scene.camera.setPixel(x, y, vecToRgba(pix, self.scene.camera.samples_per_pixel_v)) catch continue;
        }

        return self.scene.camera.image;
    }

    fn awaitTasks(self: *Self, render_node: *std.Progress.Node, tasks: []TaskTracker) !void {
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
                        try nodes.append(render_node.start(node_msg, self.chunks_per_thread));

                        i += 1;
                        std.debug.assert(i <= self.num_threads);
                        break :blk i - 1;
                    };
                    nodes.items[idx].completeOne();

                    // if (i == 1) continue;
                    completed_chunks += 1;
                    render_node.setCompletedItems(completed_chunks);

                    if (build_options.save_during_render and
                        completed_chunks % self.thread_pool.threads.len == 0)
                        try self.scene.writeToFilePath(build_options.output, .{ .png = .{} });
                } else if (!task_done) {
                    done = false;
                }
            }

            if (done or !self.thread_pool.is_running) break;
        }

        std.debug.assert(completed_chunks == self.num_chunks);
    }
};

fn renderThread(ctx: *tracer.Context, task: *TaskTracker) void {
    defer task.done.store(true, .release);
    task.thread_id = std.Thread.getCurrentId();
    tracer.trace(ctx);
}

const zero = zmath.f32x4s(0.0);
const nearly_one = zmath.f32x4s(0.999);
const v256 = zmath.f32x4s(256);

inline fn vecToRgba(v: zmath.Vec, samples_per_pixel: zmath.Vec) zigimg.color.Rgba32 {
    const rgba = zmath.clampFast(
        @sqrt(v / samples_per_pixel),
        zero,
        nearly_one,
    ) * v256; // linear to gamma

    return zigimg.color.Rgba32.initRgba(
        @intFromFloat(rgba[0]),
        @intFromFloat(rgba[1]),
        @intFromFloat(rgba[2]),
        @intFromFloat(rgba[3]),
    );
}
