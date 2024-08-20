const std = @import("std");

const AABB = @import("AABB.zig");
const hittable = @import("hittable.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;
const IntervalF32 = @import("interval.zig").IntervalF32;
const Ray = @import("Ray.zig");
const util = @import("util.zig");

const log = std.log.scoped(.BVH);

const BVH = @This();

const Ast = struct {
    left: ?*Node = null,
    right: ?*Node = null,
    bbox: AABB = AABB{},

    pub fn hit(self: *Ast, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        // if (!self.bbox.hit(r, ray_t)) return null;

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

    pub fn hit(self: *Leaf, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        var rec: ?HitRecord = null;
        var interval = ray_t;
        for (self.objects) |obj| {
            if (obj.hit(r, interval)) |res| {
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
        std.mem.sort(Hittable, objects, axis, boxCompare);

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

    pub fn bbox(self: *Node) AABB {
        return self.bbox;
    }

    pub inline fn hit(self: *Node, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        switch (self.*) {
            inline else => |*n| if (n.bbox.hit(r, ray_t)) {
                return n.hit(r, ray_t);
            },
        }

        return null;
    }
};

allocator: std.mem.Allocator,
root: *Node,

pub fn init(allocator: std.mem.Allocator, objects: hittable.HittableList, max_depth: usize) !BVH {
    defer @constCast(&objects).deinit();
    log.info("Creating BVH Tree with {} objects", .{objects.list.items.len});

    const root = try allocator.create(Node);
    try root.init(allocator, objects.list.items, max_depth, 0);

    log.debug("Reached depth of: {}, max objects: {}", .{ reached_depth, max_objects });

    return .{
        .allocator = allocator,
        .root = root,
    };
}

pub fn deinit(self: *BVH) void {
    self.root.deinit(self.allocator);
}

pub inline fn hit(self: *BVH, r: *Ray, ray_t: IntervalF32) ?HitRecord {
    return self.root.hit(r, ray_t);
}

fn boxCompare(axis_index: i32, a: Hittable, b: Hittable) bool {
    return @constCast(&a).boundingBox().axisInterval(axis_index).min < @constCast(&b).boundingBox().axisInterval(axis_index).min;
}
