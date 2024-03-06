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
    thread: usize,
};

pub fn sticky(
    context: Context,
    response: *http.Response,
    request: http.Request,
    data: Data,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    try model.thread.sticky(context, data.board, data.thread, true);
    try util.message(context, response, "Thread Updated!", user);
}

pub fn unsticky(
    context: Context,
    response: *http.Response,
    request: http.Request,
    data: Data,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    try model.thread.sticky(context, data.board, data.thread, false);
    try util.message(context, response, "Thread Updated!", user);
}
