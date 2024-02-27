const std = @import("std");
const sqlite = @import("sqlite");
const root = @import("root");

const c = root.c;
const data = root.data;
const query = root.query;
const model = root.model;
const util = model.util;

const Context = root.Context;

const Error = model.Error;

pub fn pages(context: Context, board: ?[]const u8) usize {
    return util.pages(context, "get_logs_count", .{board});
}

pub fn page(
    context: Context,
    board: ?[]const u8,
    p: usize,
) ![]data.Log {
    const config = context.config;
    const q = "get_logs_page";

    return try util.all(data.Log, context, q, .{
        board,
        config.page_length,
        p * config.page_length,
    });
}
