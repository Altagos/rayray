const std = @import("std");

const spall = @import("spall");

const Raytracer = @import("rayray").Raytracer;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try spall.init("./out/trace.spall");
    defer spall.deinit();

    spall.init_thread();
    defer spall.deinit_thread();

    const s = spall.trace(@src(), "Main", .{});

    var raytracer = try Raytracer.init(allocator);
    defer raytracer.deinit();

    const img = try raytracer.render();

    s.end();
    try img.writeToFilePath("./out/out.png", .{ .png = .{} });
}
