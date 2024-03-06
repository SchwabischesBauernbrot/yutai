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

    const user_data = try model.user.info(context, user, null);

    try util.render(response, view.user.user, .{
        .user = user,
        .user_data_opt = user_data,
        .config = context.config,
    });
}

pub fn pass(
    context: Context,
    response: *http.Response,
    request: http.Request,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const new = try util.getField(form, "new_pass");

    try model.user.updatePassword(context, user, new);

    try util.message(context, response, "Password Updated!", user);
}

pub fn theme(
    context: Context,
    response: *http.Response,
    request: http.Request,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const new = try util.getField(form, "new_theme");

    try model.user.updateTheme(context, user, new);

    try util.found(response, "/user", .{});
}
