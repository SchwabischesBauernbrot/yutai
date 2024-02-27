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
    _: http.Request,
    data: Data,
) !void {
    try model.thread.sticky(context, data.board, data.thread, true);
    try util.message(response, "Thread Updated!");
}

pub fn unsticky(
    context: Context,
    response: *http.Response,
    _: http.Request,
    data: Data,
) !void {
    try model.thread.sticky(context, data.board, data.thread, false);
    try util.message(response, "Thread Updated!");
}
