const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const view = root.view;
const model = root.model;
const handler = root.handler;
const util = handler.util;

const Context = root.Context;

pub fn delete(
    context: Context,
    response: *http.Response,
    request: http.Request,
    board: []const u8,
) !void {
    const user_opt = try util.getUserOpt(context, request);
    defer root.util.free(context.alloc, user_opt);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const posts = try util.getPosts(context.alloc, form.fields);
    defer context.alloc.free(posts);

    try model.post.deleteList(context, board, posts, request.address);

    try util.message(context, response, "Post(s) Deleted!", user_opt);
}

pub fn modDelete(
    context: Context,
    response: *http.Response,
    request: http.Request,
    board: []const u8,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const reason = form.fields.get("reason_delete") orelse "";

    const posts = try util.getPosts(context.alloc, form.fields);
    defer context.alloc.free(posts);

    try model.post.modDeleteList(context, board, posts, user, reason);

    try util.message(context, response, "Post(s) Deleted!", user);
}

pub fn globalModDelete(
    context: Context,
    response: *http.Response,
    request: http.Request,
    board: []const u8,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const reason = form.fields.get("reason_delete") orelse "";
    const permanent = form.fields.get("permanent") != null;

    const posts = try util.getPosts(context.alloc, form.fields);
    defer context.alloc.free(posts);

    if (permanent) {
        try model.post.eraseList(context, board, posts);
    } else {
        try model.post.modDeleteList(context, board, posts, user, reason);
    }

    try util.message(context, response, "Post(s) Deleted!", user);
}
