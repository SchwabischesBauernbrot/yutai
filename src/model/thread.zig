const std = @import("std");
const sqlite = @import("sqlite");
const root = @import("root");

const c = root.c;
const data = root.data;
const query = root.query;
const model = root.model;
const util = model.util;

const Context = root.Context;

const DataError = model.DataError;
const Error = model.Error;

pub fn add(
    context: Context,
    board: data.Board,
    addr: std.net.Address,
    subject: ?[]const u8,
    message: []const u8,
    email_opt: ?[]const u8,
    name_opt: ?[]const u8,
    files: [][2][]const u8,
) !void {
    var buf: [32]u8 = undefined;
    const salt = util.randStr(context.rng, &buf);
    const post = board.post_count;

    try util.beginTransaction(context);
    errdefer util.rollbackTransaction(context) catch {};

    try model.post.add(
        context,
        board,
        post,
        null,
        addr,
        subject,
        message,
        email_opt,
        name_opt,
    );
    try util.exec(context, "add_thread", .{ board.board, post, salt });
    for (files) |file| {
        try model.post_image.add(context, file[0], file[1], board, post);
    }
    try util.exec(context, "delete_old_threads", .{
        board.board,
        context.config.threadLimit(),
    });

    util.endTransaction(context) catch {};
    try model.post_image.clear(context);
}

pub fn pages(
    context: Context,
    board: data.Board,
    flags: model.user.Flags,
) usize {
    const args = .{ board.board, flags.atLeastMod() };
    return util.pages(context, "get_threads_count", args);
}

pub fn page(
    context: Context,
    board: data.Board,
    p: usize,
    flags: model.user.Flags,
) ![][]data.Thread {
    const alloc = context.alloc;
    const config = context.config;
    const q = "get_threads_page";

    const temp = try util.all(data.Thread, context, q, .{
        board.board,
        flags.atLeastMod(),
        config.page_length,
        p * config.page_length,
    });
    defer alloc.free(temp);

    return try util.pack(data.Thread, alloc, temp);
}

pub fn latestReplies(
    context: Context,
    board: data.Board,
    threads: [][]data.Thread,
    flags: model.user.Flags,
) ![][][]data.Reply {
    const alloc = context.alloc;

    var replies = try alloc.alloc([][]data.Reply, threads.len);

    for (threads, 0..) |thread, i| {
        replies[i] = try model.reply.latest(context, board, thread[0], flags);
    }

    return replies;
}

pub fn rows(
    context: Context,
    board: data.Board,
    thread: usize,
    flags: model.user.Flags,
) ![]data.Thread {
    const q = "get_thread";
    const slice = try util.all(data.Thread, context, q, .{
        thread,
        board.board,
        flags.atLeastMod(),
    });

    if (slice.len == 0) return DataError.NotFound;

    return slice;
}

pub fn catalog(
    context: Context,
    board: data.Board,
    flags: model.user.Flags,
) ![]data.CatalogThread {
    const q = "get_catalog";
    return try util.all(data.CatalogThread, context, q, .{
        board.board,
        flags.atLeastMod(),
    });
}

pub fn sticky(
    context: Context,
    board: []const u8,
    thread: usize,
    value: bool,
) !void {
    const q = "update_thread_sticky";
    try util.exec(context, q, .{ value, thread, board });
}
