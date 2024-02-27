const std = @import("std");
const sqlite = @import("sqlite");
const root = @import("root");

const c = root.c;
const data = root.data;
const query = root.query;
const model = root.model;
const util = model.util;

const Context = root.Context;

const DataError = model.DataError;
const Error = model.Error;

pub fn add(
    context: Context,
    board: []const u8,
    name: []const u8,
    description: []const u8,
    owner: []const u8,
) !void {
    const q = "add_board";

    var buf: [32]u8 = undefined;
    const salt = util.randStr(context.rng, &buf);
    util.exec(context, q, .{ board, name, description, owner, salt }) catch |err|
        return switch (err) {
        sqlite.Error.SQLiteConstraint => Error.ExistingBoard,
        else => err,
    };
}

pub fn one(context: Context, board: []const u8) !data.Board {
    const q = "get_board";
    const opt = try util.oneAlloc(data.Board, context, q, .{board});
    return opt orelse DataError.NotFound;
}

pub fn all(context: Context) ![]data.Board {
    const q = "get_boards";
    return try util.all(data.Board, context, q, .{});
}

pub fn updateName(
    context: Context,
    board: []const u8,
    new: []const u8,
) !void {
    const q = "update_board_name";
    try util.exec(context, q, .{ new, board });
}

pub fn updateDescription(
    context: Context,
    board: []const u8,
    new: []const u8,
) !void {
    const q = "update_board_description";
    try util.exec(context, q, .{ new, board });
}

pub fn remove(context: Context, board: []const u8) !void {
    const q = "delete_board";
    try util.exec(context, q, .{board});
}
