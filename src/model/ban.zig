const std = @import("std");
const sqlite = @import("sqlite");
const root = @import("root");

const c = root.c;
const data = root.data;
const query = root.query;
const model = root.model;
const util = model.util;

const Context = root.Context;
const Address = root.Address;

const Error = model.Error;

pub fn get(
    context: Context,
    board_opt: ?[]const u8,
    addr: std.net.Address,
) ![2][]data.Ban {
    const q = "get_bans";

    var buf: [64]u8 = undefined;
    const address = Address.init(addr);
    var list: [2][]data.Ban = undefined;

    const single = try bufAddressStr(&buf, address);
    list[0] = try util.all(data.Ban, context, q, .{ board_opt, single });

    var sub_list = std.ArrayList(data.Ban).init(context.alloc);
    defer sub_list.deinit();

    var i: c_int = 0;
    while (i < root.util.enumCount(Address.RangeSize)) : (i += 1) {
        const range_size: Address.RangeSize = @enumFromInt(i);
        const range = try bufAddressStr(&buf, address.range(range_size));
        const bans = try util.all(data.Ban, context, q, .{ board_opt, range });
        defer context.alloc.free(bans);
        try sub_list.appendSlice(bans);
    }

    list[1] = try sub_list.toOwnedSlice();

    return list;
}

pub fn add(
    context: Context,
    board_opt: ?[]const u8,
    hash: []const u8,
    length: i64,
    reason: []const u8,
    user: data.User,
    range_size_opt: ?Address.RangeSize,
) !void {
    const address_str = try model.address.get(context, board_opt, hash);
    defer root.util.free(context.alloc, address_str);

    var buf: [64]u8 = undefined;
    const range = if (range_size_opt) |range_size| blk: {
        const parsed = try std.net.Address.parseIp(address_str, 80);
        const range_address = Address.init(parsed).range(range_size);
        break :blk try bufAddressStr(&buf, range_address);
    } else address_str;

    try addAddress(context, board_opt, range, length, reason, user.name);
}

pub fn addAddress(
    context: Context,
    board_opt: ?[]const u8,
    address: []const u8,
    length: i64,
    reason: []const u8,
    name: []const u8,
) !void {
    const q = "add_ban";
    const expires = if (length > 0) std.time.timestamp() + length else 0;
    try util.exec(context, q, .{ board_opt, address, expires, reason, name });
}

pub const State = enum { all, expired, permanent, temporary };

pub fn pages(
    context: Context,
    board: ?[]const u8,
    comptime state: State,
) usize {
    const b = bounds(state);
    const args = .{ b.min, b.max, board };
    return util.pages(context, "get_bans_count", args);
}

pub fn page(
    context: Context,
    board: ?[]const u8,
    comptime state: State,
    p: usize,
) ![]data.Ban {
    const config = context.config;
    const q = "get_bans_page";
    const b = bounds(state);

    return try util.all(data.Ban, context, q, .{
        b.min,
        b.max,
        board,
        config.page_length,
        p *| config.page_length,
    });
}

pub fn dismiss(
    context: Context,
    user: data.User,
    reason: []const u8,
    board: ?[]const u8,
    id: usize,
) !void {
    const q = "close_ban";

    try util.exec(context, q, .{ reason, user.name, id, board });
}

fn bounds(comptime state: State) util.Bounds {
    return switch (state) {
        .all => .{ .min = 0, .max = std.math.maxInt(i64) },
        .expired => .{ .min = 1, .max = std.time.timestamp() },
        .temporary => .{
            .min = std.time.timestamp(),
            .max = std.math.maxInt(i64),
        },
        .permanent => .{},
    };
}

pub fn bufAddressStr(buf: []u8, addr: Address) ![]const u8 {
    return try std.fmt.bufPrint(buf, "{}", .{addr});
}
