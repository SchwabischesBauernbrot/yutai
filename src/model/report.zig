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

pub const State = enum { all, open, closed };

pub fn pages(
    context: Context,
    global: bool,
    board: ?[]const u8,
    comptime state: State,
) usize {
    const b = bounds(state);
    const args = .{ b.min, b.max, board, global };
    return util.pages(context, "get_reports_count", args);
}

pub fn page(
    context: Context,
    global: bool,
    board: ?[]const u8,
    comptime state: State,
    p: usize,
) ![]data.Report {
    const config = context.config;
    const q = "get_reports_page";
    const b = bounds(state);

    return try util.all(data.Report, context, q, .{
        b.min,
        b.max,
        board,
        global,
        config.page_length,
        p *| config.page_length,
    });
}

pub fn closeList(
    context: Context,
    global: bool,
    board: ?[]const u8,
    user: data.User,
    reports: [][]const u8,
    message: []const u8,
) !void {
    const q = "close_report";

    for (reports) |report| {
        try util.exec(context, q, .{
            message,
            user.name,
            report,
            board,
            global,
        });
    }
}

fn bounds(comptime state: State) util.Bounds {
    return switch (state) {
        .all => .{ .min = 0, .max = std.math.maxInt(i64) },
        .open => .{ .min = 0, .max = 0 },
        .closed => .{ .min = 1, .max = std.math.maxInt(i64) },
    };
}
