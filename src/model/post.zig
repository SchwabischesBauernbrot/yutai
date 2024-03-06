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

const DataError = model.DataError;
const Error = model.Error;

pub fn add(
    context: Context,
    board: data.Board,
    post: usize,
    thread: ?usize,
    addr: std.net.Address,
    subject: ?[]const u8,
    message: []const u8,
    email: ?[]const u8,
    name_opt: ?[]const u8,
) !void {
    const alloc = context.alloc;
    const config = context.config;

    const name = name_opt orelse config.default_name;

    var buf: [64]u8 = undefined;
    const address: ?[]const u8 = if (config.log_post_ip)
        try util.bufAddressStr(&buf, addr)
    else
        null;

    var list = try std.ArrayList(u8).initCapacity(alloc, message.len);
    defer list.deinit();

    //cache the formatted post body
    try root.view.util.writePostText(list.writer(), message);

    try util.exec(context, "add_post", .{
        post,
        thread,
        board.board,
        subject,
        list.items,
        address,
        email,
        name,
    });
}

pub fn latest(context: Context) ![]data.Post {
    const config = context.config;
    const q = "get_latest_posts";
    const limit = config.max_latest_posts;
    return try util.all(data.Post, context, q, .{limit});
}

pub fn deleteList(
    context: Context,
    board: []const u8,
    list: [][2][]const u8,
    addr: std.net.Address,
) !void {
    const q = "delete_post";

    var buf: [64]u8 = undefined;
    const address = try util.bufAddressStr(&buf, addr);

    try util.beginTransaction(context);
    errdefer util.rollbackTransaction(context) catch {};

    for (list) |pair| {
        const post = pair[1];
        errdefer util.rollbackTransaction(context) catch {};

        if (try isPoster(context, board, post, address)) {
            try util.exec(context, q, .{ null, null, post, board });
        } else {
            return DataError.InvalidCredentials;
        }
    }

    util.endTransaction(context) catch {};
}

pub fn modDeleteList(
    context: Context,
    board: []const u8,
    list: [][2][]const u8,
    mod: data.User,
    reason: []const u8,
) !void {
    const q = "delete_post";

    try util.beginTransaction(context);
    errdefer util.rollbackTransaction(context) catch {};

    for (list) |pair| {
        const post = pair[1];
        try util.exec(context, q, .{ reason, mod.name, post, board });
    }

    util.endTransaction(context) catch {};
}

pub fn eraseList(
    context: Context,
    board: []const u8,
    list: [][2][]const u8,
) !void {
    const q = "delete_post_permanent";

    try util.beginTransaction(context);
    errdefer util.rollbackTransaction(context) catch {};

    for (list) |pair| {
        const post = pair[1];
        try util.exec(context, q, .{ post, board });
    }

    util.endTransaction(context) catch {};
}

pub fn reportList(
    context: Context,
    global: bool,
    board: []const u8,
    addr: std.net.Address,
    list: [][2][]const u8,
    reason: []const u8,
) !void {
    var buf: [64]u8 = undefined;
    const address = try util.bufAddressStr(&buf, addr);

    try util.beginTransaction(context);
    errdefer util.rollbackTransaction(context) catch {};

    for (list) |pair| {
        try util.exec(
            context,
            "add_report",
            .{ board, pair[0], pair[1], reason, address, global },
        );
    }

    util.endTransaction(context) catch {};
}

pub fn isPoster(
    context: Context,
    board: []const u8,
    post: []const u8,
    user: []const u8,
) !bool {
    const q = "is_poster";
    return util.oneSize(context, q, .{ board, post, user }) != 0;
}

pub fn deleteByAddress(
    context: Context,
    board_opt: ?[]const u8,
    hash: []const u8,
    mod: []const u8,
    reason: []const u8,
) !void {
    const address = try model.address.get(context, board_opt, hash);
    defer root.util.free(context.alloc, address);

    try util.exec(context, "delete_address_posts", .{
        .reason = reason,
        .moderator = mod,
        .address = address,
        .board = board_opt,
    });
}

pub fn deleteByAddressPermanent(
    context: Context,
    hash: []const u8,
) !void {
    const address = try model.address.get(context, null, hash);
    defer root.util.free(context.alloc, address);

    std.log.info("address: {s}", .{address});

    try util.exec(context, "delete_address_posts_permanent", .{address});
}
