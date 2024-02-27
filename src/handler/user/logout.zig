const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const view = root.view;
const model = root.model;
const handler = root.handler;
const util = handler.util;

const Context = root.Context;

pub fn post(
    context: Context,
    response: *http.Response,
    request: http.Request,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    try model.user.logout(context, user);

    try util.removeToken(response);

    try util.message(response, "Session Closed!");
}
