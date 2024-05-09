const std = @import("std");

const AABB = @import("../AABB.zig");
const hittable = @import("../hittable.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;
const IntervalF32 = @import("../interval.zig").IntervalF32;
const Ray = @import("../Ray.zig");
const util = @import("../util.zig");

pub const BVH = @This();

const Node = struct {
    left: ?*Node = null,
    right: ?*Node = null,
    bbox: AABB = AABB{},
    hittable: ?Hittable = null,

    // pub fn add(self: *Node, allocator: std.mem.Allocator, object: *Hittable) void {}
    //
    pub fn init(
        self: *Node,
        allocator: std.mem.Allocator,
        objects: []hittable.Hittable,
        // start: usize,
        // end: usize,
    ) !void {
        for (0..objects.len) |idx| {
            self.bbox = AABB.initAB(&self.bbox, &objects[idx].boundingBox());
        }

        const axis = self.bbox.longestAxis();
        const object_span = objects.len;

        if (object_span == 1) {
            self.hittable = objects[0];
            self.bbox = AABB.initAB(&self.bbox, &objects[0].boundingBox());
            // std.log.info("Node.hittable = .{?}", .{self.hittable});
            return;
        }

        var left = try allocator.create(Node);
        var right = try allocator.create(Node);

        // if (object_span == 2) {
        //     try left.init(allocator, objects, start, start + 1);
        //     try right.init(allocator, objects, start + 1, start + 2);
        // } else
        if (object_span >= 2) {
            // std.log.debug("Node.init axis={} start={} end={}", .{ axis, start, end });
            if (axis == 0) {
                // break :blk&boxXCompare;
                std.mem.sort(Hittable, objects, .{}, boxXCompare);
            } else if (axis == 1) {
                // break :blk &boxYCompare;
                std.mem.sort(Hittable, objects, .{}, boxYCompare);
            } else {
                // break :blk &boxZCompare;
                std.mem.sort(Hittable, objects, .{}, boxZCompare);
            }
            // std.mem.sort(Hittable, list, null, comparator);

            const mid = object_span / 2;
            try left.init(allocator, objects[0..mid]);
            try right.init(allocator, objects[mid..]);
        }

        self.left = left;
        self.right = right;

        self.combineBbox();

        // std.log.info("Node created", .{});
    }

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        if (self.left) |l| {
            l.deinit(allocator);
            allocator.destroy(l);
        }
        if (self.right) |r| {
            r.deinit(allocator);
            allocator.destroy(r);
        }
    }

    pub fn hit(self: *Node, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        if (!self.bbox.hit(r, ray_t)) {
            return null;
        }

        if (self.hittable) |object| {
            return @constCast(&object).hit(r, ray_t);
        }

        var rec: ?HitRecord = null;
        if (self.left) |left| {
            if (left.hit(r, ray_t)) |res| {
                rec = res;
            }
        }

        if (self.right) |right| {
            const interval = blk: {
                if (rec) |rec_| {
                    break :blk IntervalF32.init(ray_t.min, rec_.t);
                }
                break :blk ray_t;
            };

            if (right.hit(r, interval)) |res| {
                rec = res;
            }
        }

        return rec;
    }

    pub fn print(self: *Node, depth: usize, side: u8) void {
        for (0..depth) |_| std.debug.print("  ", .{});

        if (side == 1) {
            std.debug.print("Left = ", .{});
        } else if (side >= 2) {
            std.debug.print("Right = ", .{});
        }

        const has_hit = if (self.hittable) |h| @constCast(&h).getName() else "Ast";
        std.debug.print("Node hittable={s}\n", .{has_hit});

        if (self.left) |left| left.print(depth + 1, 1);
        if (self.right) |right| right.print(depth + 1, 2);
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
// objects: hittable.HittableList,
root: Node,

pub fn init(allocator: std.mem.Allocator, objects: hittable.HittableList) !BVH {
    std.log.info("Creating BVH Tree with {} objects", .{objects.list.items.len});
    // return BVH.init(objects, 0, objects.list.items.len);
    var root = Node{};
    try root.init(allocator, objects.list.items);
    defer @constCast(&objects).deinit();

    // root.print(0, 0);

    return .{
        .allocator = allocator,
        // .objects = objects,
        .root = root,
    };
}

pub fn deinit(self: *BVH) void {
    self.root.deinit(self.allocator);
    // self.objects.deinit();
}

pub fn hit(self: *BVH, r: *Ray, ray_t: IntervalF32) ?HitRecord {
    return self.root.hit(r, ray_t);
}

pub fn boundingBox(self: *BVH) AABB {
    return self.root.bbox;
}

fn boxCompare(a: *Hittable, b: *Hittable, axis_index: i32) bool {
    const a_axis_interval = a.boundingBox().axisInterval(axis_index);
    const b_axis_interval = b.boundingBox().axisInterval(axis_index);
    return a_axis_interval.min > b_axis_interval.min;
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
