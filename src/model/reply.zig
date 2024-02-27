const std = @import("std");
const sqlite = @import("sqlite");
const root = @import("root");

const c = root.c;
const data = root.data;
const query = root.query;
const model = root.model;
const util = model.util;

const Context = root.Context;

const Error = model.Error;

pub fn add(
    context: Context,
    board: data.Board,
    thread: usize,
    addr: std.net.Address,
    subject: ?[]const u8,
    message: ?[]const u8,
    email_opt: ?[]const u8,
    name_opt: ?[]const u8,
    files: [][2][]const u8,
) !void {
    const sage = if (email_opt) |email|
        std.mem.eql(u8, email, "sage")
    else
        false;
    const post = board.post_count;

    try util.beginTransaction(context);
    defer util.endTransaction(context) catch {};

    try model.post.add(
        context,
        board,
        post,
        thread,
        addr,
        subject,
        message,
        email_opt,
        name_opt,
    );
    try util.exec(context, "add_reply", .{ board.board, post, sage });
    for (files) |file| {
        try model.post_image.add(context, file[0], file[1], board, post);
    }
    try util.exec(context, "update_thread_bump", .{
        board.board,
        thread,
        post,
        context.config.bump_limit,
    });
}

pub fn all(
    context: Context,
    board: data.Board,
    thread: data.Thread,
    flags: model.user.Flags,
) ![][]data.Reply {
    const alloc = context.alloc;
    const q = "get_thread_replies";

    const temp = try util.all(data.Reply, context, q, .{
        thread.post,
        board.board,
        flags.atLeastMod(),
    });
    defer alloc.free(temp);

    return try util.pack(data.Reply, alloc, temp);
}

pub fn latest(
    context: Context,
    board: data.Board,
    thread: data.Thread,
    flags: model.user.Flags,
) ![][]data.Reply {
    @setEvalBranchQuota(10000);

    const alloc = context.alloc;
    const config = context.config;
    const q = "get_thread_latest_replies";

    const temp = try util.all(data.Reply, context, q, .{
        thread.post,
        board.board,
        flags.atLeastMod(),
        config.reply_count,
    });
    defer alloc.free(temp);

    return try util.pack(data.Reply, alloc, temp);
}
