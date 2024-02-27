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

const bufAddressStr = model.util.bufAddressStr;
const ban = model.ban.addAddress;

pub fn post(
    context: Context,
    _: *http.Response,
    request: http.Request,
) !void {
    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    if (util.nullIfEmpty(form.fields.get("file"))) |filename| {
        if (util.nullIfEmpty(form.files.get(filename))) |body| {
            try check(context, request, body);
        }
    }
}

fn check(context: Context, request: http.Request, body: []const u8) !void {
    if (try getImage(context, body)) |image| {
        if (image.file_state == .banned) {
            var addr_buf: [64]u8 = undefined;
            const addr = try bufAddressStr(&addr_buf, request.address);
            const name = image.file_moderator;
            try ban(context, null, addr, 0, "banned image", name);
            return Error.BannedImage;
        }
    }
}

fn getImage(context: Context, body: []const u8) !?data.Image {
    var hash_buf: [128]u8 = undefined;
    const hash = model.util.md5(&hash_buf, body);
    return try model.post_image.get(context, hash);
}
