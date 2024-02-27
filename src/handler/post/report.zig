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
    board: []const u8,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const reason = form.fields.get("reason") orelse "";
    const global = form.fields.get("global") != null;

    const posts = try util.getPosts(context.alloc, form.fields);
    defer context.alloc.free(posts);

    const addr = request.address;
    try model.post.reportList(context, global, board, addr, posts, reason);

    try util.message(response, "Post(s) Reported!");
}
