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

const Leaf = Hittable;

const Node = union(enum) {
    ast: Ast,
    leaf: Leaf,

    pub fn init(
        self: *Node,
        allocator: std.mem.Allocator,
        objects: []hittable.Hittable,
    ) !void {
        if (objects.len == 1) {
            self.* = .{ .leaf = objects[0] };
            return;
        }

        var ast_bbox = AABB{};
        for (0..objects.len) |idx| {
            ast_bbox = AABB.initAB(&ast_bbox, &objects[idx].boundingBox());
        }

        const axis = ast_bbox.longestAxis();

        var left = try allocator.create(Node);
        var right = try allocator.create(Node);

        if (axis == 0) {
            std.mem.sort(Hittable, objects, .{}, boxXCompare);
        } else if (axis == 1) {
            std.mem.sort(Hittable, objects, .{}, boxYCompare);
        } else {
            std.mem.sort(Hittable, objects, .{}, boxZCompare);
        }

        const mid = objects.len / 2;
        try left.init(allocator, objects[0..mid]);
        try right.init(allocator, objects[mid..]);

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
            else => {},
        }
    }

    pub inline fn bbox(self: *Node) AABB {
        switch (self.*) {
            .ast => |*a| return a.bbox,
            .leaf => |l| return @constCast(&l).boundingBox(),
        }
    }

    pub inline fn hit(self: *Node, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        if (!@constCast(&self.bbox()).hit(r, ray_t)) {
            return null;
        }

        switch (self.*) {
            .ast => |*a| return a.hit(r, ray_t),
            .leaf => |*l| return l.hit(r, ray_t),
        }
    }

    fn recomputeBbox(self: *Node) AABB {
        switch (self.*) {
            .leaf => |*l| return l.boundingBox(),
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
            .leaf => |*l| std.debug.print("Leaf = {s}\n", .{l.getName()}),
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

pub fn init(allocator: std.mem.Allocator, objects: hittable.HittableList) !BVH {
    defer @constCast(&objects).deinit();
    std.log.info("Creating BVH Tree with {} objects", .{objects.list.items.len});

    const root = try allocator.create(Node);
    try root.init(allocator, objects.list.items);
    const bbox = root.recomputeBbox();

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
    if (!self.bbox.hit(r, ray_t)) {
        return null;
    }

    return self.root.hit(r, ray_t);
}

inline fn boxCompare(a: *Hittable, b: *Hittable, axis_index: i32) bool {
    const a_axis_interval = a.boundingBox().axisInterval(axis_index);
    const b_axis_interval = b.boundingBox().axisInterval(axis_index);
    return a_axis_interval.min <= b_axis_interval.min;
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
