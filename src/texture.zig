const std = @import("std");
const zm = @import("zmath");

pub const Texture = union(enum) {
    solid_color: SolidColor,
    checker_texture: CheckerTexture,

    pub fn init(alloc: std.mem.Allocator, data: anytype) !*Texture {
        const tex = try alloc.create(Texture);

        switch (@TypeOf(data)) {
            SolidColor => tex.* = .{ .solid_color = data },
            CheckerTexture => tex.* = .{ .checker_texture = data },

            else => @panic("Cannot infer Texture type of: " ++ @typeName(@TypeOf(data))),
        }

        return tex;
    }

    pub fn value(self: *Texture, u: f32, v: f32, p: zm.Vec) zm.Vec {
        switch (self.*) {
            inline else => |*n| return n.value(u, v, p),
        }
    }
};

pub const SolidColor = struct {
    albedo: zm.Vec,

    pub fn init(albedo: zm.Vec) SolidColor {
        return SolidColor{ .albedo = albedo };
    }

    pub fn rgb(r: f32, g: f32, b: f32) SolidColor {
        return init(zm.f32x4(r, g, b, 1.0));
    }

    pub fn value(self: *SolidColor, _: f32, _: f32, _: zm.Vec) zm.Vec {
        return self.albedo;
    }
};

pub const CheckerTexture = struct {
    inv_scale: f32,
    even: *Texture,
    odd: *Texture,

    pub fn init(scale: f32, even: *Texture, odd: *Texture) CheckerTexture {
        return CheckerTexture{ .inv_scale = 1 / scale, .even = even, .odd = odd };
    }

    pub fn value(self: *CheckerTexture, u: f32, v: f32, p: zm.Vec) zm.Vec {
        const x = @as(i32, @intFromFloat(@floor(self.inv_scale * p[0])));
        const y = @as(i32, @intFromFloat(@floor(self.inv_scale * p[1])));
        const z = @as(i32, @intFromFloat(@floor(self.inv_scale * p[2])));

        const is_even = @rem(x + y + z, 2) == 0;

        if (is_even) {
            return self.even.value(u, v, p);
        } else {
            return self.odd.value(u, v, p);
        }
    }
};
