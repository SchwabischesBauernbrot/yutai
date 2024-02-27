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
    message: ?[]const u8,
    email: ?[]const u8,
    name_opt: ?[]const u8,
) !void {
    const config = context.config;

    var buf: [64]u8 = undefined;
    const address = try util.bufAddressStr(&buf, addr);

    const name = name_opt orelse config.default_name;

    try model.address.add(context, board, address);
    try util.exec(context, "add_post", .{
        post,
        thread,
        board.board,
        subject,
        message,
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
    defer util.endTransaction(context) catch {};

    for (list) |pair| {
        const post = pair[1];
        errdefer util.rollbackTransaction(context) catch {};

        if (try isPoster(context, board, post, address)) {
            try util.exec(context, q, .{ null, null, post, board });
        } else {
            return DataError.InvalidCredentials;
        }
    }
}

pub fn modDeleteList(
    context: Context,
    board: []const u8,
    list: [][2][]const u8,
    user: data.User,
    reason: []const u8,
) !void {
    const q = "delete_post";
    for (list) |pair| {
        const post = pair[1];
        try util.exec(context, q, .{ reason, user.name, post, board });
    }
}

pub fn eraseList(
    context: Context,
    board: []const u8,
    list: [][2][]const u8,
) !void {
    for (list) |pair| {
        const post = pair[1];
        try util.exec(context, "delete_post_permanent", .{ post, board });
    }
}

pub fn reportList(
    context: Context,
    global: bool,
    board_name: []const u8,
    addr: std.net.Address,
    list: [][2][]const u8,
    reason: []const u8,
) !void {
    var buf: [64]u8 = undefined;
    const address = try util.bufAddressStr(&buf, addr);

    const board: ?data.Board = if (global)
        null
    else
        try model.board.one(context, board_name);
    defer root.util.free(context.alloc, board);

    try model.address.add(context, board, address);

    for (list) |pair| {
        try util.exec(
            context,
            "add_report",
            .{ board_name, pair[0], pair[1], reason, address, global },
        );
    }
}

pub fn isPoster(
    context: Context,
    board: []const u8,
    post: []const u8,
    address: []const u8,
) !bool {
    const opt = try util.one(i32, context, "is_poster", .{
        board,
        post,
        address,
    });
    return opt.? != 0;
}
