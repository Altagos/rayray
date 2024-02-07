const std = @import("std");

pub const Raytracer = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *const Self) void {
        _ = self;
    }

    pub fn render(self: *Self) void {
        _ = self;
    }
};

pub const Camera = struct {};
