const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const view = root.view;
const model = root.model;
const handler = root.handler;
const util = handler.util;

const Context = root.Context;

pub fn erase(
    context: Context,
    response: *http.Response,
    request: http.Request,
    hash: []const u8,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    try model.post_image.permanentRemove(context, hash, user);
    try util.message(response, "Image Erased!");
}

pub fn ban(
    context: Context,
    response: *http.Response,
    request: http.Request,
    hash: []const u8,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    try model.post_image.ban(context, hash, user);
    try util.message(response, "Image Banned!");
}
