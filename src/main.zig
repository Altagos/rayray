const Raytracer = @import("rayray").Raytracer;

pub fn main() !void {
    const raytracer = Raytracer.init();
    defer raytracer.deinit();
}
