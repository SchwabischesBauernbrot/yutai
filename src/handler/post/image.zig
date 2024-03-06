const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const view = root.view;
const model = root.model;
const handler = root.handler;
const util = handler.util;

const Context = root.Context;

pub const Data = struct {
    board: []const u8,
    id: []const u8,
};

pub fn delete(
    context: Context,
    response: *http.Response,
    request: http.Request,
    data: Data,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    try model.post_image.remove(context, data.id, user);
    try util.message(context, response, "Image Deleted!", user);
}
