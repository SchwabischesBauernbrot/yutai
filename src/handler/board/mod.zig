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
    board_name: []const u8,
) !void {
    const user_opt = try util.getUserOpt(context, request);
    defer root.util.free(context.alloc, user_opt);

    const board = try model.board.one(context, board_name);
    defer root.util.free(context.alloc, board);

    const user_data = try model.user.info(context, user_opt, board_name);

    const mods = try model.mod.all(context, board);
    defer root.util.free(context.alloc, mods);

    try util.render(response, view.board.mod, .{
        .board = board,
        .mods = mods,
        .user_data_opt = user_data,
        .config = context.config,
    });
}

pub fn name(
    context: Context,
    response: *http.Response,
    request: http.Request,
    board: []const u8,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const new = try util.getField(form, "new_name");

    try model.board.updateName(context, board, new);

    try util.found(response, "/{s}/mod", .{board});
}

pub fn description(
    context: Context,
    response: *http.Response,
    request: http.Request,
    board: []const u8,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const new = try util.getField(form, "new_description");

    try model.board.updateDescription(context, board, new);

    try util.found(response, "/{s}/mod", .{board});
}

pub fn add(
    context: Context,
    response: *http.Response,
    request: http.Request,
    board: []const u8,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const new_data = try util.getField(form, "new_mod");

    try model.mod.add(context, board, new_data);
    try util.found(response, "/{s}/mod", .{board});
}

pub const RemoveData = struct {
    board: []const u8,
    name: []const u8,
};

pub fn remove(
    context: Context,
    response: *http.Response,
    _: http.Request,
    args: RemoveData,
) !void {
    try model.mod.remove(context, args.board, args.name);
    try util.found(response, "/{s}/mod", .{args.board});
}
