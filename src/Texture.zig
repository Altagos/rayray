const zm = @import("zmath");

pub const SolidColor = struct {
    albedo: zm.Vec,

    pub fn init(albedo: zm.Vec) SolidColor {
        return .{ .albedo = albedo };
    }

    pub fn rgb(r: f32, g: f32, b: f32) SolidColor {
        return init(zm.f32x4(r, g, b, 1.0));
    }

    pub fn value(self: *SolidColor, _: f32, _: f32, _: zm.Vec) zm.Vec {
        return self.albedo;
    }
};
