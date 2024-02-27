const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const model = root.model;
const handler = root.handler;
const filter = root.filter;

const Context = root.Context;
const Flags = model.user.Flags;

const Error = filter.Error;

pub const atLeastRoot = global(Flags.at_least_root);
pub const atLeastGlobalMod = global(Flags.at_least_global_mod);
pub const atLeastOwner = local(Flags.at_least_owner);
pub const atLeastMod = local(Flags.at_least_mod);
pub const isUser = global(.{ .user = true });

const Global = fn (Context, *http.Response, http.Request) Error!void;
const Local = fn (
    Context,
    *http.Response,
    http.Request,
    board: []const u8,
) Error!void;

fn global(comptime mask: model.user.Flags) Global {
    return struct {
        pub fn f(
            context: Context,
            _: *http.Response,
            request: http.Request,
        ) Error!void {
            try any(context, request, null, mask);
        }
    }.f;
}

fn local(comptime mask: model.user.Flags) Local {
    return struct {
        pub fn f(
            context: Context,
            _: *http.Response,
            request: http.Request,
            board: []const u8,
        ) Error!void {
            try any(context, request, board, mask);
        }
    }.f;
}

fn any(
    context: Context,
    request: http.Request,
    board_opt: ?[]const u8,
    comptime mask: model.user.Flags,
) !void {
    const user = try handler.util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    const user_data = try model.user.info(context, user, board_opt);
    const flags = model.user.flags(user_data);
    if (!flags.any(mask)) return Error.InvalidCredentials;
}
