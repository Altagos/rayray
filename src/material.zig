const math = @import("std").math;

const zm = @import("zmath");

const hittable = @import("hittable.zig");
const Ray = @import("ray.zig");
const util = @import("util.zig");

pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,
    dielectric: Dielectric,

    pub fn lambertian(albedo: zm.Vec) Material {
        return .{ .lambertian = .{ .albedo = albedo } };
    }

    pub fn metal(albedo: zm.Vec, fuzz: f32) Material {
        return .{ .metal = .{ .albedo = albedo, .fuzz = if (fuzz < 1) fuzz else 1.0 } };
    }

    pub fn dielectric(refraction_index: f32) Material {
        return .{ .dielectric = .{ .refraction_index = refraction_index } };
    }

    pub fn scatter(self: *Material, r: *Ray, rec: *hittable.HitRecord, attenuation: *zm.Vec) ?Ray {
        return switch (self.*) {
            .lambertian => |*lambert| lambert.scatter(rec, attenuation),
            .metal => |*met| met.scatter(r, rec, attenuation),
            .dielectric => |*die| die.scatter(r, rec, attenuation),
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
    /// fuzz < 1
    fuzz: f32,

    pub fn scatter(self: *Metal, r: *Ray, rec: *hittable.HitRecord, attenuation: *zm.Vec) ?Ray {
        const reflected = util.reflect(zm.normalize3(r.dir), rec.normal);
        const scattered = Ray.init(rec.p, reflected + zm.f32x4s(self.fuzz) * util.randomUnitVec());
        attenuation.* = self.albedo;
        return if (zm.dot3(scattered.dir, rec.normal)[0] > 0) scattered else null;
    }
};

pub const Dielectric = struct {
    refraction_index: f32,

    pub fn scatter(self: *Dielectric, r: *Ray, rec: *hittable.HitRecord, attenuation: *zm.Vec) ?Ray {
        attenuation.* = zm.f32x4s(1.0);
        const ri = if (rec.front_face) (1.0 / self.refraction_index) else self.refraction_index;

        const unit_direction = zm.normalize3(r.dir);
        const cos_theta = @min(zm.dot3(-unit_direction, rec.normal)[0], 1.0);
        const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

        const cannot_refract = ri * sin_theta > 1.0;
        const direction = blk: {
            if (cannot_refract or reflectance(cos_theta, ri) > util.randomF32()) {
                break :blk util.reflect(unit_direction, rec.normal);
            } else {
                break :blk util.refract(unit_direction, rec.normal, ri);
            }
        };

        return Ray.init(rec.p, direction);
    }

    fn reflectance(cosine: f32, refraction_index: f32) f32 {
        var r0 = (1 - refraction_index) / (1 + refraction_index);
        r0 = r0 * r0;
        return r0 + (1 - r0) * math.pow(f32, 1 - cosine, 5);
    }
};
