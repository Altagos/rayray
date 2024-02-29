const std = @import("std");

const a = @import("a");
const spall = @import("spall");

const Raytracer = @import("rayray").Raytracer;

pub const std_options = .{
    .log_level = .debug,
    .logFn = a.log.logFn,
};

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
    std.log.info("Image rendered", .{});

    s.end();

    const s_saving = spall.trace(@src(), "Write Image", .{});
    defer s_saving.end();
    try img.writeToFilePath("./out/out.png", .{ .png = .{} });
    std.log.info("Image saved to: out/out.ong", .{});
}
