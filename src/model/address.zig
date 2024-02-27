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
    board_opt: ?data.Board,
    address: []const u8,
) !void {
    if (board_opt) |board| {
        try addLocal(context, board, address);
    }
    try addGlobal(context, address);
}

fn addLocal(
    context: Context,
    board: data.Board,
    address: []const u8,
) !void {
    const q = "add_address";
    const hash = try util.sha256Salt(address, board.address_salt);
    try util.exec(context, q, .{ board.board, address, &hash });
}

fn addGlobal(context: Context, address: []const u8) !void {
    const q = "add_address";
    const hash = try util.sha256Salt(address, context.config.address_salt);
    try util.exec(context, q, .{ null, address, &hash });
}

pub fn get(
    context: Context,
    board: ?[]const u8,
    hash: []const u8,
) ![]const u8 {
    const q = "get_address";
    const args = .{ board, hash };
    const opt = try util.oneAlloc([]const u8, context, q, args);
    return opt orelse DataError.UnknownAddress;
}
