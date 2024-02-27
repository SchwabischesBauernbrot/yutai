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
    const boards = try model.board.all(context);
    defer root.util.free(context.alloc, boards);

    const entries = try model.entry.all(context);
    defer root.util.free(context.alloc, entries);

    const posts = try model.post.latest(context);
    defer root.util.free(context.alloc, posts);

    const images = try model.post_image.latest(context);
    defer root.util.free(context.alloc, images);

    const stats = try model.stats.get(context);
    defer root.util.free(context.alloc, stats);

    const user_opt = try util.getUserOpt(context, request);
    defer root.util.free(context.alloc, user_opt);

    const user_data = try model.user.info(context, user_opt, null);

    try util.render(response, view.home, .{
        .config = context.config,
        .boards = boards,
        .news = entries,
        .recent_posts = posts,
        .recent_images = images,
        .stats = stats,
        .user_data_opt = user_data,
    });
}

pub fn post(
    context: Context,
    response: *http.Response,
    request: http.Request,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const subject = try util.getField(form, "subject");
    const message = try util.getField(form, "message");

    try model.entry.add(context, subject, message, user);

    try util.message(response, "New Entry Added!");
}
