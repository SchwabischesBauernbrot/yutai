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
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    const boards = try model.board.all(context);
    defer root.util.free(context.alloc, boards);

    const mods = try model.mod.all(context, null);
    defer root.util.free(context.alloc, mods);

    const user_data = try model.user.info(context, user, null);

    try util.render(response, view.global.mod, .{
        .user = user,
        .boards = boards,
        .mods = mods,
        .user_data_opt = user_data,
        .config = context.config,
    });
}

pub fn addMod(
    context: Context,
    response: *http.Response,
    request: http.Request,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const new_data = try util.getField(form, "new_mod");

    try model.mod.add(context, null, new_data);
    try util.found(response, "/mod", .{});
}

pub fn removeMod(
    context: Context,
    response: *http.Response,
    _: http.Request,
    name: []const u8,
) !void {
    try model.mod.remove(context, null, name);
    try util.found(response, "/mod", .{});
}

pub fn addBoard(
    context: Context,
    response: *http.Response,
    request: http.Request,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const board = try util.getField(form, "board");
    const name = try util.getField(form, "name");
    const description = try util.getField(form, "description");
    const owner = try util.getField(form, "owner");

    try model.board.add(context, board, name, description, owner);
    try util.found(response, "/{s}/", .{board});
}

pub fn removeBoard(
    context: Context,
    response: *http.Response,
    _: http.Request,
    name: []const u8,
) !void {
    try model.board.remove(context, name);
    try util.found(response, "/mod", .{});
}
