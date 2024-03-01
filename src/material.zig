const zm = @import("zmath");

const hittable = @import("hittable.zig");
const Ray = @import("ray.zig");
const util = @import("util.zig");

pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,

    pub fn lambertian(albedo: zm.Vec) Material {
        return .{ .lambertian = .{ .albedo = albedo } };
    }

    pub fn metal(albedo: zm.Vec) Material {
        return .{ .metal = .{ .albedo = albedo } };
    }

    pub fn scatter(self: *Material, r: *Ray, rec: *hittable.HitRecord, attenuation: *zm.Vec) ?Ray {
        return switch (self.*) {
            .lambertian => |*lambert| lambert.scatter(rec, attenuation),
            .metal => |*met| met.scatter(r, rec, attenuation),
        };
    }
};

pub const Lambertian = struct {
    albedo: zm.Vec,

    pub fn scatter(self: *Lambertian, rec: *hittable.HitRecord, attenuation: *zm.Vec) ?Ray {
        var scatter_dir = rec.normal + util.randomUnitVec();

        if (util.nearZero(scatter_dir)) scatter_dir = rec.normal;

        attenuation.* = self.albedo;
        return Ray.init(rec.p, scatter_dir);
    }
};

pub const Metal = struct {
    albedo: zm.Vec,

    pub fn scatter(self: *Metal, r: *Ray, rec: *hittable.HitRecord, attenuation: *zm.Vec) ?Ray {
        const reflected = util.reflect(zm.normalize3(r.dir), rec.normal);
        attenuation.* = self.albedo;
        return Ray.init(rec.p, reflected);
    }
};
