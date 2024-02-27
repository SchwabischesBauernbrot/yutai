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
    page: ?i32,
};

pub fn get(
    context: Context,
    response: *http.Response,
    request: http.Request,
    args: Data,
) !void {
    const user_opt = try util.getUserOpt(context, request);
    defer root.util.free(context.alloc, user_opt);

    const board = try model.board.one(context, args.board);
    defer root.util.free(context.alloc, board);

    const user_data = try model.user.info(context, user_opt, args.board);

    const flags = model.user.flags(user_data);

    const page = try util.getOptPage(args.page);
    const pages = model.thread.pages(context, board, flags);
    try util.checkPage(page, pages);

    const threads = try model.thread.page(context, board, page, flags);
    defer root.util.free(context.alloc, threads);

    const replies = try model.thread.latestReplies(
        context,
        board,
        threads,
        flags,
    );
    defer root.util.free(context.alloc, replies);

    try util.render(response, view.board, .{
        .board = board,
        .threads = threads,
        .replies = replies,
        .index = true,
        .page = page,
        .pages = pages,
        .user_data_opt = user_data,
        .config = context.config,
    });
}

pub fn post(
    context: Context,
    response: *http.Response,
    request: http.Request,
    name: []const u8,
) !void {
    const board = try model.board.one(context, name);
    defer root.util.free(context.alloc, board);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const subject = util.nullIfEmpty(form.fields.get("subject"));
    const message = util.nullIfEmpty(form.fields.get("body"));
    const email = util.nullIfEmpty(form.fields.get("email"));
    const opt = util.nullIfEmpty(form.fields.get("name"));

    const files = try util.getFiles(context.alloc, form);
    defer context.alloc.free(files);

    try model.thread.add(
        context,
        board,
        request.address,
        subject,
        message,
        email,
        opt,
        files,
    );

    try util.found(response, "/{s}/res/{}", .{
        board.board,
        board.post_count,
    });
}

pub fn redirect(
    _: Context,
    response: *http.Response,
    _: http.Request,
    name: []const u8,
) !void {
    try util.moved(response, "/{s}/", .{name});
}
