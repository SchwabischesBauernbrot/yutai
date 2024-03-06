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

pub fn add(
    context: Context,
    subject: []const u8,
    body: []const u8,
    html: bool,
    user: data.User,
) !void {
    const q = "add_entry";
    try util.exec(context, q, .{ subject, body, html, user.name });
}

pub fn all(context: Context) ![]data.Entry {
    const q = "get_entries";
    return try util.all(data.Entry, context, q, .{});
}
