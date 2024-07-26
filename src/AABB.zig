const zm = @import("zmath");

const HitRecord = @import("hittable.zig").HitRecord;
const Interval = @import("interval.zig").IntervalF32;
const Ray = @import("Ray.zig");

const AABB = @This();

x: Interval = Interval.empty,
y: Interval = Interval.empty,
z: Interval = Interval.empty,

pub fn init(x: Interval, y: Interval, z: Interval) AABB {
    return AABB{ .x = x, .y = y, .z = z };
}

pub fn initP(a: zm.Vec, b: zm.Vec) AABB {
    // Treat the two points a and b as extrema for the bounding box, so we don't require a
    // particular minimum/maximum coordinate order.
    return AABB{
        .x = blk: {
            if (a[0] <= b[0]) break :blk Interval.init(a[0], b[0]) else break :blk Interval.init(b[0], a[0]);
        },
        .y = blk: {
            if (a[1] <= b[1]) break :blk Interval.init(a[1], b[1]) else break :blk Interval.init(b[1], a[1]);
        },
        .z = blk: {
            if (a[2] <= b[2]) break :blk Interval.init(a[2], b[2]) else break :blk Interval.init(b[2], a[2]);
        },
    };
}

pub fn initAB(a: *const AABB, b: *const AABB) AABB {
    return AABB{
        .x = Interval.initI(a.x, b.x),
        .y = Interval.initI(a.y, b.y),
        .z = Interval.initI(a.z, b.z),
    };
}

pub fn axisInterval(self: *const AABB, n: i32) Interval {
    if (n == 1) return self.y;
    if (n == 2) return self.z;
    return self.x;
}

pub fn hit(self: *AABB, r: *Ray, ray_t: Interval) bool {
    if (ray_t.max <= ray_t.min) return false;

    const ray_orig = r.orig;
    const ray_dir = r.dir;

    var t = ray_t;

    var axis: u8 = 0;
    while (axis < 3) : (axis += 1) {
        const ax = self.axisInterval(@intCast(axis));
        const adinv = 1.0 / ray_dir[axis];

        const t0 = (ax.min - ray_orig[axis]) * adinv;
        const t1 = (ax.max - ray_orig[axis]) * adinv;

        if (t0 < t1) {
            if (t0 > t.min) t.min = t0;
            if (t1 < t.max) t.max = t1;
        } else {
            if (t1 > t.min) t.min = t1;
            if (t0 < t.max) t.max = t0;
        }

        if (t.max <= t.min) return false;
    }

    return true;
}

pub fn longestAxis(self: *AABB) i32 {
    if (self.x.size() > self.y.size()) {
        if (self.x.size() > self.z.size()) {
            return 0;
        } else return 2;
    } else {
        if (self.y.size() > self.z.size()) {
            return 1;
        } else return 2;
    }
}
