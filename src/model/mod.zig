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

pub fn all(context: Context, opt: ?data.Board) ![]data.Mod {
    const q = "get_mods";
    const name: ?[]const u8 = if (opt) |board| board.board else null;
    return try util.all(data.Mod, context, q, .{name});
}

pub fn add(context: Context, board: ?[]const u8, mod: []const u8) !void {
    const q = "add_moderator";
    util.exec(context, q, .{ mod, board }) catch |err| return switch (err) {
        sqlite.Error.SQLiteConstraint => Error.ExistingMod,
        else => err,
    };
}

pub fn remove(context: Context, board: ?[]const u8, mod: []const u8) !void {
    const q = "delete_moderator";
    return try util.exec(context, q, .{ mod, board });
}
