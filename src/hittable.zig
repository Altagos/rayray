const std = @import("std");

const zm = @import("zmath");

const IntervalF32 = @import("a").interval.IntervalF32;
const Material = @import("material.zig").Material;
const Ray = @import("ray.zig");

// Hittable Objects
pub const Sphere = @import("hittable/sphere.zig");

pub const HitRecord = struct {
    p: zm.Vec,
    normal: zm.Vec = zm.f32x4s(1.0),
    mat: *Material,
    t: f32,
    front_face: bool = true,

    pub fn setFaceNormal(self: *HitRecord, r: *Ray, outward_normal: zm.Vec) void {
        self.front_face = zm.dot3(r.dir, outward_normal)[0] < 0.0;
        self.normal = if (self.front_face) outward_normal else -outward_normal;
    }
};

pub const Hittable = union(enum) {
    sphere: Sphere,

    pub fn sphere(s: Sphere) Hittable {
        return .{ .sphere = s };
    }

    pub fn hit(self: *Hittable, r: *Ray, ray_t: IntervalF32) ?HitRecord {
        switch (self.*) {
            .sphere => |*s| {
                return s.hit(r, ray_t);
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
