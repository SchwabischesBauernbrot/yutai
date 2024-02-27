const std = @import("std");
const builtin = @import("builtin");

pub const Address = union(enum) {
    ipv4: IPv4,
    ipv6: IPv6,

    pub const RangeSize = enum(u32) {
        small = 0,
        large = 1,
    };

    pub const IPv4 = struct {
        value: [4]u8,

        pub fn format(
            self: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("{}.{}.{}.{}", .{
                self.value[0],
                self.value[1],
                self.value[2],
                self.value[3],
            });
        }

        pub fn range(self: *const @This(), size: RangeSize) Address {
            const bits: usize = switch (size) {
                .small => 8,
                .large => 12,
            };
            return Address{ .ipv4 = .{
                .value = rangeBits(4, self.value, bits),
            } };
        }
    };

    pub const IPv6 = struct {
        value: [16]u8,

        pub fn format(
            self: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            if (std.mem.eql(
                u8,
                self.value[0..12],
                &[_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff },
            )) {
                try std.fmt.format(writer, "::ffff:{}.{}.{}.{}", .{
                    self.value[12],
                    self.value[13],
                    self.value[14],
                    self.value[15],
                });
                return;
            }
            const big_endian_parts = @as(*align(1) const [8]u16, @ptrCast(&self.value));
            const native_endian_parts = switch (builtin.target.cpu.arch.endian()) {
                .Big => big_endian_parts.*,
                .Little => blk: {
                    var buf: [8]u16 = undefined;
                    for (big_endian_parts, 0..) |part, i| {
                        buf[i] = std.mem.bigToNative(u16, part);
                    }
                    break :blk buf;
                },
            };
            var i: usize = 0;
            var abbrv = false;
            while (i < native_endian_parts.len) : (i += 1) {
                if (native_endian_parts[i] == 0) {
                    if (!abbrv) {
                        try writer.writeAll(if (i == 0) "::" else ":");
                        abbrv = true;
                    }
                    continue;
                }
                try std.fmt.format(writer, "{x}", .{native_endian_parts[i]});
                if (i != native_endian_parts.len - 1) {
                    try writer.writeAll(":");
                }
            }
        }

        pub fn range(self: *const @This(), size: RangeSize) Address {
            const bits: usize = switch (size) {
                .small => 80,
                .large => 96,
            };
            return Address{ .ipv6 = .{
                .value = rangeBits(16, self.value, bits),
            } };
        }
    };

    pub fn format(
        value: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (value) {
            .ipv4 => |a| try a.format(fmt, options, writer),
            .ipv6 => |a| try a.format(fmt, options, writer),
        }
    }

    pub fn init(address: std.net.Address) @This() {
        return switch (address.any.family) {
            std.os.AF.INET => .{ .ipv4 = .{
                .value = @as(*const [4]u8, @ptrCast(&address.in.sa.addr)).*,
            } },
            std.os.AF.INET6 => .{ .ipv6 = .{
                .value = @as(*const [16]u8, @ptrCast(&address.in6.sa.addr)).*,
            } },
            else => unreachable,
        };
    }

    pub fn range(self: *const @This(), size: RangeSize) @This() {
        return switch (self.*) {
            .ipv4 => |v| v.range(size),
            .ipv6 => |v| v.range(size),
        };
    }
};

pub fn rangeBits(comptime len: usize, arr: [len]u8, rbits: usize) [len]u8 {
    var range: [len]u8 = arr;

    var bits = rbits;
    var i: u32 = 0;
    while (bits > 0) : ({
        i += 1;
        bits = if (bits > 8) bits - 8 else 0;
    }) {
        const tmp = @min(bits, 8);
        const shift = @as(u3, @intCast(tmp % 8));
        const mask: u8 = ~(@as(u8, 255) >> shift);

        const offset = len - 1 - i;
        range[offset] &= mask;
    }

    return range;
}
