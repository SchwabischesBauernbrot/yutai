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
    hash: []const u8,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    const user_data = try model.user.info(context, user, null);

    try util.render(response, view.global.ban, .{
        .hash = hash,
        .config = context.config,
        .user_data_opt = user_data,
    });
}

pub fn post(
    context: Context,
    response: *http.Response,
    request: http.Request,
    hash: []const u8,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const length_str = try util.getField(form, "length");
    const reason = try util.getField(form, "reason");
    const type_str = try util.getField(form, "type");

    const ban_images = form.fields.get("ban_images") != null;
    const images = form.fields.get("images") != null;
    const images_permanent = form.fields.get("images_permanent") != null;
    const posts = form.fields.get("posts") != null;
    const posts_permanent = form.fields.get("posts_permanent") != null;

    const @"type" = util.parseBanType(type_str);
    const length = try util.parseLength(length_str);

    try model.ban.add(context, null, hash, length, reason, user, @"type");

    if (ban_images) {
        try model.post_image.banByAddress(context, hash, user.name);
    } else if (images) {
        if (images_permanent) {
            try model.post_image.deleteByAddressPermanent(context, hash, user.name);
        } else {
            try model.post_image.deleteByAddress(context, null, hash, user.name);
        }
    }

    if (posts) {
        if (posts_permanent) {
            try model.post.deleteByAddressPermanent(context, hash);
        } else {
            try model.post.deleteByAddress(context, null, hash, user.name, reason);
        }
    }

    try util.message(context, response, "User Banned!", user);
}
