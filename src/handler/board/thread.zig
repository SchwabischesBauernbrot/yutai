const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const view = root.view;
const model = root.model;
const handler = root.handler;
const util = handler.util;

const Context = root.Context;

pub const Data = struct {
    board: []const u8,
    thread: usize,
};

pub fn get(
    context: Context,
    response: *http.Response,
    request: http.Request,
    args: Data,
) !void {
    const user_opt = try util.getUserOpt(context, request);
    defer root.util.free(context.alloc, user_opt);

    const user_data = try model.user.info(context, user_opt, args.board);

    const board = try model.board.one(context, args.board);
    defer root.util.free(context.alloc, board);

    const flags = model.user.flags(user_data);

    const rows = try model.thread.rows(context, board, args.thread, flags);
    defer root.util.free(context.alloc, rows);

    const replies = try model.reply.all(context, board, rows[0], flags);
    defer root.util.free(context.alloc, replies);

    try util.render(response, view.board.thread, .{
        .board = board,
        .thread_rows = rows,
        .replies_rows = replies,
        .index = false,
        .user_data_opt = user_data,
        .config = context.config,
    });
}

pub fn post(
    context: Context,
    response: *http.Response,
    request: http.Request,
    args: Data,
) !void {
    const board = try model.board.one(context, args.board);
    defer root.util.free(context.alloc, board);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const subject = try util.nullIfEmpty(form, "subject");
    const message = try util.getMessage(context.config, form, "body");
    const email = try util.nullIfEmpty(form, "email");
    const name = try util.nullIfEmpty(form, "name");

    const files = try util.getFiles(context.alloc, form);
    defer context.alloc.free(files);

    try model.reply.add(
        context,
        board,
        args.thread,
        request.address,
        subject,
        message,
        email,
        name,
        files,
    );

    try util.found(response, "/{s}/res/{}", .{
        board.board,
        args.thread,
    });
}
