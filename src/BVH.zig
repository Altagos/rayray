const std = @import("std");

const AABB = @import("AABB.zig");
const hittable = @import("hittable.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;
const IntervalF32 = @import("interval.zig").IntervalF32;
const Ray = @import("Ray.zig");
const util = @import("util.zig");

pub const BVH = @This();

const Ast = struct {
    left: ?*Node = null,
    right: ?*Node = null,
    bbox: AABB = AABB{},

    pub fn hit(self: *Ast, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        if (!self.bbox.hit(r, ray_t)) return null;

        var rec: ?HitRecord = null;
        var interval = ray_t;
        if (self.left) |left| {
            if (left.hit(r, interval)) |res| {
                interval = IntervalF32.init(ray_t.min, res.t);
                rec = res;
            }
        }

        if (self.right) |right| {
            if (right.hit(r, interval)) |res| {
                return res;
            }
        }

        return rec;
    }
};

const Leaf = struct {
    objects: []Hittable,
    bbox: AABB,

    pub inline fn hit(self: *Leaf, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        var rec: ?HitRecord = null;
        var interval = ray_t;
        for (self.objects) |obj| {
            if (@constCast(&obj).hit(r, interval)) |res| {
                interval = IntervalF32.init(ray_t.min, res.t);
                rec = res;
            }
        }
        return rec;
    }
};

threadlocal var reached_depth: usize = 0;
threadlocal var max_objects: usize = 0;

const Node = union(enum) {
    ast: Ast,
    leaf: Leaf,

    pub fn init(
        self: *Node,
        allocator: std.mem.Allocator,
        objects: []Hittable,
        max_depth: usize,
        depth: usize,
    ) !void {
        if (reached_depth < depth) reached_depth = depth;

        var ast_bbox = AABB{};
        for (0..objects.len) |idx| {
            ast_bbox = AABB.initAB(&ast_bbox, &objects[idx].boundingBox());
        }

        if (depth >= max_depth or objects.len <= 2) {
            if (max_objects < objects.len) max_objects = objects.len;
            self.* = .{ .leaf = .{ .objects = objects, .bbox = ast_bbox } };
            return;
        }

        const axis = ast_bbox.longestAxis();

        if (axis == 0) {
            std.mem.sort(Hittable, objects, .{}, boxXCompare);
        } else if (axis == 1) {
            std.mem.sort(Hittable, objects, .{}, boxYCompare);
        } else {
            std.mem.sort(Hittable, objects, .{}, boxZCompare);
        }

        var left = try allocator.create(Node);
        var right = try allocator.create(Node);

        const mid = objects.len / 2;
        try left.init(allocator, objects[0..mid], max_depth, depth + 1);
        try right.init(allocator, objects[mid..], max_depth, depth + 1);

        self.* = .{ .ast = .{
            .left = left,
            .right = right,
            .bbox = ast_bbox,
        } };
    }

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .ast => |*a| {
                if (a.left) |left| {
                    left.deinit(allocator);
                    allocator.destroy(left);
                }
                if (a.right) |right| {
                    right.deinit(allocator);
                    allocator.destroy(right);
                }
            },
            .leaf => |*l| {
                allocator.destroy(&l.objects);
            },
        }
    }

    pub inline fn bbox(self: *Node) AABB {
        switch (self.*) {
            .ast => |*a| return a.bbox,
            .leaf => |*l| return l.bbox,
        }
    }

    pub inline fn hit(self: *Node, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        // if (@constCast(&self.bbox()).hit(r, ray_t)) {

        // }

        switch (self.*) {
            inline else => |*n| if (n.bbox.hit(r, ray_t)) {
                return n.hit(r, ray_t);
            } else {
                return null;
            },
        }
    }

    fn recomputeBbox(self: *Node) AABB {
        switch (self.*) {
            .leaf => |*l| return l.bbox,
            .ast => |*a| {
                var left = AABB{};
                var right = AABB{};

                if (a.left) |l| left = l.recomputeBbox();
                if (a.right) |r| right = r.recomputeBbox();

                a.bbox = AABB.initAB(&left, &right);
                return a.bbox;
            },
        }
    }

    pub fn print(self: *Node, depth: usize, side: u8) void {
        for (0..depth) |_| std.debug.print("  ", .{});

        switch (self.*) {
            .ast => |*a| {
                if (side == 1) {
                    std.debug.print("Left = ", .{});
                } else if (side >= 2) {
                    std.debug.print("Right = ", .{});
                }

                std.debug.print("Ast\n", .{});

                if (a.left) |left| left.print(depth + 1, 1);
                if (a.right) |right| right.print(depth + 1, 2);
            },
            .leaf => |*l| std.debug.print("Leafs = {}\n", .{l}),
        }
    }

    fn combineBbox(self: *Node) void {
        var left = AABB{};
        var right = AABB{};

        if (self.left) |l| left = l.bbox;
        if (self.right) |r| right = r.bbox;

        self.bbox = AABB.initAB(&left, &right);
    }
};

allocator: std.mem.Allocator,
root: *Node,
bbox: AABB,

pub fn init(allocator: std.mem.Allocator, objects: hittable.HittableList, max_depth: usize) !BVH {
    defer @constCast(&objects).deinit();
    std.log.info("Creating BVH Tree with {} objects", .{objects.list.items.len});

    const root = try allocator.create(Node);
    try root.init(allocator, objects.list.items, max_depth, 0);
    const bbox = root.recomputeBbox();

    std.log.debug("Reached depth of: {}, max objects: {}", .{ reached_depth, max_objects });

    // root.print(0, 0);
    return .{
        .allocator = allocator,
        .root = root,
        .bbox = bbox,
    };
}

pub fn deinit(self: *BVH) void {
    self.root.deinit(self.allocator);
}

pub inline fn hit(self: *BVH, r: *Ray, ray_t: IntervalF32) ?HitRecord {
    if (self.bbox.hit(r, ray_t)) {
        return self.root.hit(r, ray_t);
    }

    return null;
}

inline fn boxCompare(a: *Hittable, b: *Hittable, axis_index: i32) bool {
    const a_axis_interval = a.boundingBox().axisInterval(axis_index);
    const b_axis_interval = b.boundingBox().axisInterval(axis_index);
    return a_axis_interval.min < b_axis_interval.min;
}

fn boxXCompare(_: @TypeOf(.{}), a: Hittable, b: Hittable) bool {
    return boxCompare(@constCast(&a), @constCast(&b), 0);
}

fn boxYCompare(_: @TypeOf(.{}), a: Hittable, b: Hittable) bool {
    return boxCompare(@constCast(&a), @constCast(&b), 1);
}

fn boxZCompare(_: @TypeOf(.{}), a: Hittable, b: Hittable) bool {
    return boxCompare(@constCast(&a), @constCast(&b), 2);
}
