const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const data = root.data;
const model = root.model;
const handler = root.handler;
const filter = root.filter;
const util = handler.util;

const Context = root.Context;

const Error = filter.Error;

const ban = model.ban.addNetAddress;

pub fn post(
    context: Context,
    _: *http.Response,
    request: http.Request,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const files = try util.getFiles(context.alloc, form);
    defer context.alloc.free(files);

    for (files) |file| {
        const body = file[1];
        try check(context, request.address, body);
    }
}

fn check(context: Context, address: std.net.Address, body: []const u8) !void {
    if (try getImage(context, body)) |image| {
        defer root.util.free(context.alloc, image);
        if (image.file_state == .banned) {
            const name = image.file_moderator;
            try ban(context, address, "banned image", name);
            return Error.BannedImage;
        }
    }
}

fn getImage(context: Context, body: []const u8) !?data.Image {
    var hash_buf: [128]u8 = undefined;
    const hash = model.util.md5(&hash_buf, body);
    return try model.post_image.get(context, hash);
}
