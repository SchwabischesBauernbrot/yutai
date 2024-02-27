const std = @import("std");
const root = @import("root");

const c = root.c;
const model = root.model;
const handler = root.handler;

pub fn readFileAlloc(alloc: std.mem.Allocator, path: []const u8) ![]const u8 {
    const max_size = 1024 * 1024 * 12;
    return try std.fs.cwd().readFileAlloc(alloc, path, max_size);
}

pub fn free(allocator: std.mem.Allocator, obj: anytype) void {
    const Type = @TypeOf(obj);

    switch (@typeInfo(Type)) {
        .Array => for (obj) |item| {
            free(allocator, item);
        },
        .Struct => |info| inline for (info.fields) |field| {
            free(allocator, @field(obj, field.name));
        },
        .Union => |info| if (info.tag_type) |Tag| {
            inline for (info.fields) |field| {
                if (obj == @field(Tag, field.name)) {
                    free(allocator, @field(obj, field.name));
                }
            }
        },
        .Pointer => |info| switch (info.size) {
            .Slice => {
                if (Type == []const u8) {
                    allocator.free(obj);
                } else {
                    for (obj) |item| {
                        free(allocator, item);
                    }
                    allocator.free(obj);
                }
            },
            .One => {
                free(allocator, obj.*);
                allocator.destroy(obj);
            },
            else => {},
        },
        .Optional => {
            if (obj) |v| {
                free(allocator, v);
            }
        },
        else => {},
    }
}

pub fn timeToStringZ(alloc: std.mem.Allocator, time: usize) ![:0]const u8 {
    var buffer: [128]u8 = undefined;
    const local = c.localtime(&@as(c_long, @intCast(time)));
    const len = c.strftime(&buffer, buffer.len, "%D", local);
    return try alloc.dupeZ(u8, buffer[0..len]);
}

pub fn enumCount(comptime Type: type) c_int {
    return @as(c_int, @intCast(std.meta.fields(Type).len));
}
