const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const model = root.model;
const handler = root.handler;
const filter = root.filter;
const view = root.view;
const util = handler.util;

const Context = root.Context;

const Error = filter.Error;

pub fn global(
    context: Context,
    response: *http.Response,
    request: http.Request,
) !void {
    try any(context, request, response, null);
}

pub fn local(
    context: Context,
    response: *http.Response,
    request: http.Request,
    board: []const u8,
) !void {
    try any(context, request, response, board);
}

fn any(
    context: Context,
    request: http.Request,
    response: *http.Response,
    opt: ?[]const u8,
) !void {
    const user_opt = try util.getUserOpt(context, request);
    defer root.util.free(context.alloc, user_opt);

    const bans = try model.ban.get(context, opt, request.address);
    defer root.util.free(context.alloc, bans);

    const user_data_opt = try model.user.info(context, user_opt, opt);

    if (bans[0].len + bans[1].len == 0) return;

    const ip_bans = bans[0];
    const range_bans = bans[1];

    response.status_code = .forbidden;
    try util.render(
        response,
        view.user.banned,
        .{
            .bans = ip_bans,
            .range_bans = range_bans,
            .user_data_opt = user_data_opt,
            .config = context.config,
        },
    );

    return Error.BannedAddress;
}
