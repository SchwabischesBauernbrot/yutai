const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const view = root.view;
const model = root.model;
const handler = root.handler;
const util = handler.util;

const Context = root.Context;

pub fn get(_: Context, response: *http.Response, _: http.Request) !void {
    try util.render(response, view.register, view);
}

pub fn post(
    context: Context,
    response: *http.Response,
    request: http.Request,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const name = try util.getField(form, "name");
    const pass = try util.getField(form, "pass");

    const session = try model.user.add(context, name, pass);
    defer root.util.free(context.alloc, session.token);

    try util.setToken(response, session.token, session.expires);
    try util.found(response, "/user", .{});
}
