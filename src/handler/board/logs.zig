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
    page: i32,
};

pub fn get(
    context: Context,
    response: *http.Response,
    request: http.Request,
    args: Data,
) !void {
    const board = try model.board.one(context, args.board);
    defer root.util.free(context.alloc, board);

    const page = try util.getPage(args.page);
    const pages = model.log.pages(context, args.board);
    try util.checkPage(page, pages);

    const logs = try model.log.page(context, args.board, page);
    defer root.util.free(context.alloc, logs);

    const user_opt = try util.getUserOpt(context, request);
    defer root.util.free(context.alloc, user_opt);

    const user_data = try model.user.info(context, user_opt, args.board);

    try util.render(response, view.logs, .{
        .logs = logs,
        .board = board,
        .page = page,
        .pages = pages,
        .user_data_opt = user_data,
        .config = context.config,
    });
}
