const std = @import("std");

const zigimg = @import("zigimg");

const Camera = @import("Camera.zig");
const hittable = @import("hittable.zig");
const Material = @import("material.zig").Material;
const Texture = @import("texture.zig").Texture;

allocator: std.mem.Allocator,

camera: Camera = undefined,
world: hittable.HittableList,

materials: std.ArrayList(*Material),
textures: std.ArrayList(*Texture),

const Self = @This();

pub fn init(alloc: std.mem.Allocator) Self {
    return Self{
        .allocator = alloc,
        .world = hittable.HittableList.init(alloc),
        .materials = std.ArrayList(*Material).init(alloc),
        .textures = std.ArrayList(*Texture).init(alloc),
    };
}

pub fn deinit(self: *Self) void {
    self.camera.deinit();
    self.world.deinit();

    for (self.materials.items) |mat| {
        self.allocator.destroy(mat);
    }

    for (self.textures.items) |tex| {
        self.allocator.destroy(tex);
    }

    self.materials.deinit();
    self.textures.deinit();
}

pub fn createMaterial(self: *Self, mat: anytype) !*Material {
    const ptr = try Material.init(self.allocator, mat);
    try self.materials.append(ptr);
    return ptr;
}

pub fn createTexture(self: *Self, tex: anytype) !*Texture {
    const ptr = try Texture.init(self.allocator, tex);
    try self.textures.append(ptr);
    return ptr;
}

pub fn setCamera(self: *Self, cam: Camera.Options) !void {
    self.camera = try Camera.init(self.allocator, cam);
}

pub fn writeToFilePath(self: *Self, path: []const u8, opts: zigimg.Image.EncoderOptions) !void {
    try self.camera.image.writeToFilePath(path, opts);
}
