const std = @import("std");
const sqlite = @import("sqlite");
const root = @import("root");

const c = root.c;
const query = root.query;

const Context = root.Context;
const Address = root.Address;

pub const Bounds = struct { min: i64 = 0, max: i64 = 0 };

pub fn bufAddressStr(buf: []u8, addr: std.net.Address) ![]const u8 {
    return try std.fmt.bufPrint(buf, "{}", .{Address.init(addr)});
}

pub fn bufImagePath(
    buf: []u8,
    hash: []const u8,
    extension: []const u8,
) ![]const u8 {
    return try std.fmt.bufPrint(buf, "static/images/{s}{s}", .{
        hash,
        extension,
    });
}

pub fn bufThumbnailPath(
    buf: []u8,
    hash: []const u8,
) ![]const u8 {
    return try std.fmt.bufPrint(buf, "static/thumbs/{s}.jpg", .{hash});
}

pub fn bufThumbnailPathZ(
    buf: []u8,
    hash: []const u8,
) ![:0]const u8 {
    return try std.fmt.bufPrintZ(buf, "static/thumbs/{s}.jpg", .{hash});
}

pub fn bufPrintHex(buffer: []u8, digest: []const u8) []const u8 {
    return std.fmt.bufPrint(
        buffer,
        "{x:0>2}",
        .{std.fmt.fmtSliceHexLower(digest)},
    ) catch unreachable;
}

//generic hash
fn gh(comptime Func: type, buffer: []u8, data: []const u8) []const u8 {
    var digest: [Func.digest_length]u8 = undefined;
    Func.hash(data, &digest, .{});
    return bufPrintHex(buffer, &digest);
}

pub fn md5(buffer: []u8, data: []const u8) []const u8 {
    return gh(std.crypto.hash.Md5, buffer, data);
}

pub fn sha256(buffer: []u8, data: []const u8) []const u8 {
    return gh(std.crypto.hash.sha2.Sha256, buffer, data);
}

pub fn sha256BuffLen() usize {
    return std.crypto.hash.sha2.Sha256.digest_length * 2;
}

pub fn sha256Salt(
    data: []const u8,
    salt: []const u8,
) ![sha256BuffLen()]u8 {
    var buff: [256]u8 = undefined;
    var hash_buff: [sha256BuffLen()]u8 = undefined;
    const base = try std.fmt.bufPrint(&buff, "{s}{s}", .{ data, salt });
    _ = sha256(&hash_buff, base);
    return hash_buff;
}

pub fn randStr(rng: std.rand.Random, buffer: []u8) []const u8 {
    for (buffer) |*p|
        p.* = rng.intRangeAtMostBiased(u8, 'a', 'z');
    return buffer;
}

pub fn exec(context: Context, comptime sql: []const u8, data: anytype) !void {
    const stmt = &@field(context.statements, sql).s;
    stmt.reset();
    try stmt.exec(.{}, data);
}

pub fn one(
    comptime T: type,
    context: Context,
    comptime sql: []const u8,
    data: anytype,
) !?T {
    const stmt = &@field(context.statements, sql).s;
    stmt.reset();
    return try stmt.one(T, .{}, data);
}

pub fn oneSize(
    context: Context,
    comptime sql: []const u8,
    data: anytype,
) usize {
    return (one(usize, context, sql, data) catch @as(usize, 0)) orelse 0;
}

pub fn oneAlloc(
    comptime T: type,
    context: Context,
    comptime sql: []const u8,
    data: anytype,
) !?T {
    const alloc = context.alloc;
    const stmt = &@field(context.statements, sql).s;
    stmt.reset();
    return try stmt.oneAlloc(T, alloc, .{}, data);
}

pub fn all(
    comptime T: type,
    context: Context,
    comptime sql: []const u8,
    data: anytype,
) ![]T {
    const alloc = context.alloc;
    const stmt = &@field(context.statements, sql).s;
    stmt.reset();
    return try stmt.all(T, alloc, .{}, data);
}

pub fn beginTransaction(context: Context) !void {
    try exec(context, "begin", .{});
}

pub fn endTransaction(context: Context) !void {
    try exec(context, "end", .{});
}

pub fn rollbackTransaction(context: Context) !void {
    try exec(context, "rollback", .{});
}

pub fn pack(
    comptime Type: type,
    alloc: std.mem.Allocator,
    slice: []Type,
) ![][]Type {
    var list = std.ArrayList([]Type).init(alloc);
    defer list.deinit();

    var last: usize = 0;
    for (slice, 0..) |item, i| {
        if (item.post != slice[last].post) {
            const temp = try alloc.dupe(Type, slice[last..i]);
            try list.append(temp);
            last = i;
        }
    }
    if (slice.len != 0) {
        const temp = try alloc.dupe(Type, slice[last..]);
        try list.append(temp);
    }

    return list.toOwnedSlice();
}

pub fn pages(
    context: Context,
    comptime q: []const u8,
    args: anytype,
) usize {
    const divCeil = std.math.divCeil;
    const count = oneSize(context, q, args);
    const temp = divCeil(usize, count, context.config.page_length) catch 1;
    return @max(temp, 1);
}

pub fn deleteFileZ(path: [:0]const u8) !void {
    var cwd = std.fs.cwd();
    try cwd.deleteFileZ(path.ptr);
}

pub fn deleteFile(path: []const u8) !void {
    var cwd = std.fs.cwd();
    try cwd.deleteFile(path);
}
