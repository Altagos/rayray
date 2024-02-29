const std = @import("std");

const zm = @import("zmath");

const IntervalF32 = @import("interval.zig").IntervalF32;
const Ray = @import("ray.zig");
pub const Sphere = @import("hittable/sphere.zig");

pub const HitRecord = struct {
    p: zm.Vec,
    normal: zm.Vec = zm.f32x4s(1.0),
    t: f32,
    front_face: bool = true,

    pub fn setFaceNormal(self: *HitRecord, r: *Ray, outward_normal: zm.Vec) void {
        self.front_face = zm.dot3(r.dir, outward_normal)[0] < 0.0;
        self.normal = if (self.front_face) outward_normal else -outward_normal;
    }
};

pub const HittableType = enum {
    sphere,
};

pub const Hittable = union(HittableType) {
    sphere: Sphere,

    pub fn initSphere(sphere: Sphere) Hittable {
        return .{ .sphere = sphere };
    }

    pub fn hit(self: *Hittable, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        switch (self.*) {
            .sphere => |*sphere| {
                return sphere.hit(r, ray_t);
            },
        }

        return null;
    }
};

pub const HittableList = struct {
    list: std.ArrayList(Hittable),

    pub fn init(allocator: std.mem.Allocator) HittableList {
        const list = std.ArrayList(Hittable).init(allocator);

        return .{ .list = list };
    }

    pub fn deinit(self: *HittableList) void {
        self.list.deinit();
    }

    pub fn add(self: *HittableList, item: Hittable) !void {
        try self.list.append(item);
    }

    pub fn hit(self: *HittableList, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        var rec: ?HitRecord = null;
        var hit_anything = false;
        var closest_so_far = ray_t.max;

        for (self.list.items) |*object| {
            if (object.hit(r, IntervalF32.init(ray_t.min, closest_so_far))) |new_rec| {
                rec = new_rec;
                hit_anything = true;
                closest_so_far = new_rec.t;
            }
        }

        return rec;
    }
};
