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
    address: []const u8,
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

    try util.render(response, view.ban, .{
        .board = args.board,
        .address = args.address,
        .user_data_opt = user_data,
    });
}

pub fn post(
    context: Context,
    response: *http.Response,
    request: http.Request,
    args: Data,
) !void {
    const board = args.board;
    const address = args.address;

    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const length_str = try util.getField(form, "length");
    const reason = try util.getField(form, "reason");
    const range_str = try util.getField(form, "range");

    const range = try util.parseRange(range_str);
    const length = try util.parseLength(length_str);

    try model.ban.add(context, board, address, length, reason, user, range);

    try util.message(response, "Address Banned!");
}
