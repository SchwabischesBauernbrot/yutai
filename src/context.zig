const std = @import("std");
const root = @import("root");
const sqlite = @import("sqlite");

const Config = root.Config;
const Statements = root.Statements;

pub const Cache = struct {
    favicon_opt: ?std.fs.File,

    pub fn init(name_opt: ?[]const u8) !@This() {
        return .{ .favicon_opt = if (name_opt) |name| blk: {
            var buf: [64]u8 = undefined;
            const path = try std.fmt.bufPrint(&buf, "static/{s}", .{name});
            var dir = std.fs.cwd();
            break :blk try dir.openFile(path, .{});
        } else null };
    }

    pub fn deinit(self: *@This()) void {
        if (self.favicon_opt) |file| file.close();
    }
};

alloc: std.mem.Allocator = undefined,
rng: std.rand.Random = undefined,
db: *sqlite.Db = undefined,
config: Config = undefined,
statements: *Statements.List = undefined,
cache: Cache,
