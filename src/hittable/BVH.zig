const std = @import("std");

const AABB = @import("../AABB.zig");
const hittable = @import("../hittable.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;
const IntervalF32 = @import("../interval.zig").IntervalF32;
const Ray = @import("../Ray.zig");
const util = @import("../util.zig");

pub const BVH = @This();

objects: *hittable.HittableList,
left: *Hittable,
right: *Hittable,
bbox: AABB,

pub fn initL(objects: *hittable.HittableList) BVH {
    std.log.info("starting to create BVH", .{});
    return BVH.init(objects, 0, objects.list.items.len);
}

pub fn init(objects: *hittable.HittableList, start: usize, end: usize) BVH {
    const list = objects.list.items;
    var bbox = AABB{};
    for (start..end) |idx| {
        bbox = AABB.initAB(&bbox, &list[idx].boundingBox());
    }

    const axis = bbox.longestAxis();

    // const comparator = blk: {
    //     if (axis == 0) {
    //         break :blk &boxXCompare;
    //     } else if (axis == 1) {
    //         break :blk &boxYCompare;
    //     }
    //     break :blk &boxZCompare;
    // };

    const object_span = end - start;

    var left = &list[start];
    var right = &list[start];
    if (object_span == 2) {
        left = &list[start];
        right = &list[start + 1];
    } else if (object_span > 2) {
        std.log.debug("BVH.init axis={} start={} end={}", .{axis, start, end});
        if (axis == 0) {
            // break :blk&boxXCompare;
            std.mem.sort(Hittable, list, .{}, boxXCompare);
        } else if (axis == 1) {
            // break :blk &boxYCompare;
            std.mem.sort(Hittable, list, .{}, boxYCompare);
        } else {
            // break :blk &boxZCompare;
            std.mem.sort(Hittable, list, .{}, boxZCompare);
        }
        // std.mem.sort(Hittable, list, null, comparator);

        const mid = start + object_span / 2;
        left = @constCast(&Hittable.bvh(BVH.init(objects, start, mid)));
        right = @constCast(&Hittable.bvh(BVH.init(objects, mid, end)));
    }

    std.log.info("BVH created", .{});

    return .{
        .objects = objects,
        .left = left,
        .right = right,
        .bbox = bbox,
    };
}

pub fn hit(self: *BVH, r: *Ray, ray_t: IntervalF32) ?HitRecord {
    if (!self.bbox.hit(r, ray_t)) {
        return null;
    }

    if (self.left.hit(r, ray_t)) |rec| return rec;
    if (self.right.hit(r, ray_t)) |rec| return rec;
    return null;
}

pub fn boundingBox(self: *BVH) AABB {
    return self.bbox;
}

fn boxCompare(a: *Hittable, b: *Hittable, axis_index: i32) bool {
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
