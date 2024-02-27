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
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const posts = try util.getPosts(context.alloc, form.fields);
    defer context.alloc.free(posts);

    try model.post.deleteList(context, board, posts, request.address);

    try util.message(response, "Post(s) Deleted!");
}

pub fn modDelete(
    context: Context,
    response: *http.Response,
    request: http.Request,
    board: []const u8,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    const reason = form.fields.get("reason_delete") orelse "";

    const posts = try util.getPosts(context.alloc, form.fields);
    defer context.alloc.free(posts);

    try model.post.modDeleteList(context, board, posts, user, reason);

    try util.message(response, "Post(s) Deleted!");
}

pub fn globalModDelete(
    context: Context,
    response: *http.Response,
    request: http.Request,
    board: []const u8,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    const reason = form.fields.get("reason_delete") orelse "";
    const permanent = form.fields.get("permanent") != null;

    const posts = try util.getPosts(context.alloc, form.fields);
    defer context.alloc.free(posts);

    if (permanent) {
        try model.post.eraseList(context, board, posts);
    } else {
        try model.post.modDeleteList(context, board, posts, user, reason);
    }

    try util.message(response, "Post(s) Deleted!");
}
