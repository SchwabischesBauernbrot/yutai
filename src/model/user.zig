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

pub const Session = struct {
    token: []const u8,
    expires: i64,
};

pub const Data = struct {
    pub const Board = struct {
        board: []const u8,
        is_mod: bool,
        is_owner: bool = false,
    };

    name: []const u8,
    is_root: bool,
    is_global_mod: bool,
    board_data_opt: ?Board = null,
};

pub const Flags = packed struct {
    mod: bool = false,
    owner: bool = false,
    global_mod: bool = false,
    root: bool = false,
    user: bool = false,

    pub const at_least_root: @This() = .{
        .root = true,
    };
    pub const at_least_owner: @This() = .{
        .root = true,
        .owner = true,
    };
    pub const at_least_global_mod: @This() = .{
        .root = true,
        .global_mod = true,
    };
    pub const at_least_mod: @This() = .{
        .root = true,
        .owner = true,
        .global_mod = true,
        .mod = true,
    };

    pub fn atLeastMod(self: *const @This()) bool {
        return self.any(at_least_mod);
    }

    pub fn atLeastGlobalMod(self: *const @This()) bool {
        return self.any(at_least_global_mod);
    }

    pub fn any(self: *const @This(), mask: @This()) bool {
        const Int = @typeInfo(@This()).Struct.backing_integer.?;
        const a = @as(Int, @bitCast(self.*));
        const b = @as(Int, @bitCast(mask));
        return (a & b) != 0;
    }
};

pub fn info(
    context: Context,
    user_opt: ?data.User,
    board_opt: ?[]const u8,
) !?Data {
    return if (user_opt) |user| .{
        .name = user.name,
        .is_global_mod = try isGlobalMod(context, user.name),
        .is_root = isRoot(context, user.name),
        .board_data_opt = if (board_opt) |board| .{
            .board = board,
            .is_mod = try isMod(context, board, user.name),
            .is_owner = try isOwner(context, board, user.name),
        } else null,
    } else null;
}

pub fn flags(user_data_opt: ?Data) Flags {
    var ret = Flags{};
    if (user_data_opt) |user_data| {
        ret.user = true;
        ret.root = user_data.is_root;
        ret.global_mod = user_data.is_global_mod;
        if (user_data.board_data_opt) |board_data| {
            ret.mod = board_data.is_mod;
            ret.owner = board_data.is_owner;
        }
    }
    return ret;
}

pub fn add(
    context: Context,
    name: []const u8,
    pass: []const u8,
) !Session {
    const rng = context.rng;
    const q = "add_user";
    const salt_size = 0x20;

    var buf: [salt_size]u8 = undefined;
    const salt = util.randStr(rng, &buf);
    const hash = try util.sha256Salt(pass, salt);

    util.exec(context, q, .{ name, &hash, salt }) catch |err|
        return switch (err) {
        sqlite.Error.SQLiteConstraint => Error.ExistingUser,
        else => err,
    };

    return try newSession(
        context,
        data.User{ .name = name, .pass = &hash, .salt = salt },
    );
}

pub fn login(
    context: Context,
    name: []const u8,
    pass: []const u8,
) !Session {
    const q = "get_salt";

    const salt_opt = (try util.oneAlloc([]const u8, context, q, .{name}));
    defer root.util.free(context.alloc, salt_opt);

    const salt = salt_opt orelse return DataError.InvalidCredentials;
    const hash = try util.sha256Salt(pass, salt);

    const user = try one(context, name, &hash);
    defer root.util.free(context.alloc, user);

    return try newSession(context, user);
}

pub fn logout(context: Context, user: data.User) !void {
    try endSession(context, user);
}

pub fn updatePassword(
    context: Context,
    user: data.User,
    new: []const u8,
) !void {
    const rng = context.rng;
    const q = "update_user";
    const salt_size = 0x20;

    var buf: [salt_size]u8 = undefined;
    const salt = util.randStr(rng, &buf);
    const hash = try util.sha256Salt(new, salt);

    try util.exec(context, q, .{ &hash, salt, user.name });
}

pub fn optSession(context: Context, session: []const u8) !?data.User {
    const q = "get_session";
    return try util.oneAlloc(data.User, context, q, .{session});
}

pub fn fromSession(context: Context, session: []const u8) !data.User {
    return (try optSession(context, session)) orelse DataError.InvalidCredentials;
}

pub fn one(context: Context, name: []const u8, hash: []const u8) !data.User {
    return (try opt(context, name, hash)) orelse DataError.InvalidCredentials;
}

pub fn opt(context: Context, name: []const u8, hash: []const u8) !?data.User {
    const q = "get_user";
    return try util.oneAlloc(data.User, context, q, .{ name, hash });
}

pub fn isMod(context: Context, board: []const u8, user: []const u8) !bool {
    return (try util.one(i32, context, "is_mod", .{ user, board })).? != 0;
}

pub fn isGlobalMod(context: Context, user: []const u8) !bool {
    return (try util.one(i32, context, "is_mod", .{ user, null })).? != 0;
}

fn newSession(context: Context, user: data.User) !Session {
    const rng = context.rng;
    const alloc = context.alloc;

    const date = std.time.timestamp();
    const length = 60 * 60 * 24; //TODO let the user change this
    const expires = date + length;

    var session = try alloc.alloc(u8, 64);
    const str = util.randStr(rng, session);

    try updateSession(context, user, str, expires);
    return Session{ .token = str, .expires = expires };
}

fn endSession(context: Context, user: data.User) !void {
    try updateSession(context, user, null, 0);
}

fn updateSession(
    context: Context,
    user: data.User,
    session: ?[]const u8,
    expires: i64,
) !void {
    const q = "update_session";
    try util.exec(context, q, .{ session, expires, user.name });
}

fn isRoot(context: Context, user: []const u8) bool {
    return std.mem.eql(u8, user, context.config.root_user);
}

pub fn isOwner(context: Context, board: []const u8, user: []const u8) !bool {
    return (try util.one(i32, context, "is_owner", .{ user, board })).? != 0;
}
