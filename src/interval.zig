const std = @import("std");

pub const IntervalU8 = Interval(u8);
pub const IntervalU16 = Interval(u16);
pub const IntervalU32 = Interval(u32);
pub const IntervalU64 = Interval(u64);
pub const IntervalUsize = Interval(usize);

pub const IntervalI8 = Interval(i8);
pub const IntervalI16 = Interval(i16);
pub const IntervalI32 = Interval(i32);
pub const IntervalI64 = Interval(i64);
pub const IntervalIsize = Interval(isize);

pub const IntervalF32 = Interval(f32);
pub const IntervalF64 = Interval(f64);

pub const IntervalIteratorType = enum {
    inclusive,
    exclusive,
};

pub fn Interval(comptime T: type) type {
    if (@typeInfo(T) == .Int) {
        return struct {
            const Self = @This();

            pub const empty: Self = .{ .min = std.math.inf(T), .max = -std.math.inf(T) };
            pub const universe: Self = .{ .min = -std.math.inf(T), .max = std.math.inf(T) };

            pub const Iterator = struct {
                interval: Self,
                current: T,

                lower_boundry: IntervalIteratorType = .inclusive,
                upper_boundry: IntervalIteratorType = .exclusive,

                pub fn init(
                    interval: Self,
                    lower_boundry: IntervalIteratorType,
                    upper_boundry: IntervalIteratorType,
                ) Iterator {
                    return .{
                        .interval = interval,
                        .current = if (lower_boundry == .inclusive) interval.min else interval.min + 1,
                        .lower_boundry = lower_boundry,
                        .upper_boundry = upper_boundry,
                    };
                }

                pub fn next(self: *Iterator) ?T {
                    self.current += 1;
                    if (self.current < self.interval.max or (self.current == self.interval.max and self.upper_boundry == .inclusive)) {
                        return self.current;
                    } else return null;
                }

                pub fn nextInc(self: *Iterator) ?T {
                    self.current += 1;
                    return if (self.current <= self.interval.max) self.current else null;
                }

                pub fn nextExc(self: *Iterator) ?T {
                    self.current += 1;
                    return if (self.current < self.interval.max) self.current else null;
                }
            };

            min: T,
            max: T,

            pub fn init(min: T, max: T) Interval {
                return .{ .min = min, .max = max };
            }

            pub fn contains(self: *const Self, x: T) bool {
                return self.min <= x and x <= self.max;
            }

            pub fn surrounds(self: *const Self, x: T) bool {
                return self.min < x and x < self.max;
            }

            pub fn iter(self: *const Self) Iterator {
                return Iterator{
                    .interval = self.*,
                    .current = self.min,
                };
            }
        };
    } else if (@typeInfo(T) == .Float) {
        return struct {
            pub const empty: @This() = .{ .min = std.math.inf(T), .max = -std.math.inf(T) };
            pub const universe: @This() = .{ .min = -std.math.inf(T), .max = std.math.inf(T) };

            const Self = @This();

            min: T,
            max: T,

            pub fn init(min: T, max: T) Self {
                return .{ .min = min, .max = max };
            }

            pub fn contains(self: *const Self, x: T) bool {
                return self.min <= x and x <= self.max;
            }

            pub fn surrounds(self: *const Self, x: T) bool {
                return self.min < x and x < self.max;
            }
        };
    } else {
        @compileError("Interval only supports Int and Float Types!");
    }
}
