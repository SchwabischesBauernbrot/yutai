const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const view = root.view;
const model = root.model;
const handler = root.handler;
const util = handler.util;

const Context = root.Context;

pub fn get(
    context: Context,
    response: *http.Response,
    request: http.Request,
    name: []const u8,
) !void {
    const user_opt = try util.getUserOpt(context, request);
    defer root.util.free(context.alloc, user_opt);

    const board = try model.board.one(context, name);
    defer root.util.free(context.alloc, board);

    const user_data = try model.user.info(context, user_opt, name);

    const flags = model.user.flags(user_data);

    const threads = try model.thread.catalog(context, board, flags);
    defer root.util.free(context.alloc, threads);

    try util.render(response, view.board.catalog, .{
        .board = board,
        .threads = threads,
        .user_data_opt = user_data,
        .config = context.config,
    });
}
