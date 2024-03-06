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
    hash: []const u8,
};

pub fn get(
    context: Context,
    response: *http.Response,
    request: http.Request,
    args: Data,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    const board = try model.board.one(context, args.board);
    defer root.util.free(context.alloc, board);

    const user_data = try model.user.info(context, user, args.board);

    try util.render(response, view.board.ban, .{
        .board = board,
        .hash = args.hash,
        .config = context.config,
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

    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const length_str = try util.getField(form, "length");
    const reason = try util.getField(form, "reason");
    const type_str = try util.getField(form, "type");
    const images = form.fields.get("images") != null;
    const posts = form.fields.get("posts") != null;

    const @"type" = util.parseBanType(type_str);
    const length = try util.parseLength(length_str);

    try model.ban.add(context, board, args.hash, length, reason, user, @"type");

    if (images) {
        try model.post_image.deleteByAddress(context, board, args.hash, user.name);
    }

    if (posts) {
        try model.post.deleteByAddress(context, board, args.hash, user.name, reason);
    }

    try util.message(context, response, "User Banned!", user);
}
