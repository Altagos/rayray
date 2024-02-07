const std = @import("std");

pub const Raytracer = struct {
    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn deinit(self: *const Self) void {
        _ = self;
    }

    pub fn render(self: *Self) void {
        _ = self;
    }
};
