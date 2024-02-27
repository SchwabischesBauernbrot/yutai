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
    page_arg: i64,
) !void {
    const page = try util.getPage(@as(i32, @intCast(page_arg)));
    const pages = model.log.pages(context, null);
    try util.checkPage(page, pages);

    const logs = try model.log.page(context, null, page);
    defer root.util.free(context.alloc, logs);

    const user_opt = try util.getUserOpt(context, request);
    defer root.util.free(context.alloc, user_opt);

    const user_data = try model.user.info(context, user_opt, null);

    try util.render(response, view.global.logs, .{
        .logs = logs,
        .page = page,
        .pages = pages,
        .user_data_opt = user_data,
        .config = context.config,
    });
}
