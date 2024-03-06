const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const data = root.data;
const model = root.model;
const handler = root.handler;
const filter = root.filter;
const util = handler.util;

const Context = root.Context;

const Error = filter.Error;

pub fn global(
    context: Context,
    _: *http.Response,
    request: http.Request,
) !void {
    try add(context, null, request.address);
}

pub fn local(
    context: Context,
    _: *http.Response,
    request: http.Request,
    name: []const u8,
) !void {
    const board = try model.board.one(context, name);
    defer root.util.free(context.alloc, board);

    try add(context, board, request.address);
}

fn add(
    context: Context,
    board_opt: ?data.Board,
    address: std.net.Address,
) !void {
    try model.address.addNet(context, board_opt, address);
}
