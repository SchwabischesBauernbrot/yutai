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
    const captcha = try model.captcha.get(context, request.address);
    defer root.util.free(context.alloc, captcha);

    var dir = std.fs.cwd();
    const file = try dir.openFile(captcha.path, .{});
    defer file.close();

    const header = "Cache-Control";
    const value = "no-cache";
    try response.headers.put(header, value);

    try http.FileServer.serveFile(response, "captcha.jpg", file);
}
