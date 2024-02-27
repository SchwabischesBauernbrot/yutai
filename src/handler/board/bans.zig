const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const view = root.view;
const model = root.model;
const handler = root.handler;
const util = handler.util;

const Context = root.Context;

pub const DismissData = struct {
    board: []const u8,
    ban_id: usize,
};

pub fn post(
    context: Context,
    response: *http.Response,
    request: http.Request,
    args: DismissData,
) !void {
    const board = args.board;
    const id = args.ban_id;

    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    try model.ban.dismiss(context, user, "dismissed", board, id);

    try util.message(response, "Ban(s) Dismissed!");
}

pub const all = bansPage(.all);
pub const expired = bansPage(.expired);
pub const temporary = bansPage(.temporary);
pub const permanent = bansPage(.permanent);

fn bansPage(
    comptime state: model.ban.State,
) HandlerFunc {
    return struct {
        pub fn f(
            context: Context,
            response: *http.Response,
            request: http.Request,
            args: Data,
        ) anyerror!void {
            const board = try model.board.one(context, args.board);
            defer root.util.free(context.alloc, board);

            const page = try util.getPage(args.page);
            const pages = model.ban.pages(context, args.board, state);
            try util.checkPage(page, pages);

            const bans = try model.ban.page(context, args.board, state, page);
            defer root.util.free(context.alloc, bans);

            const user_opt = try util.getUserOpt(context, request);
            defer root.util.free(context.alloc, user_opt);

            const user_data = try model.user.info(
                context,
                user_opt,
                args.board,
            );

            try util.render(response, view.bans, .{
                .bans = bans,
                .board = board,
                .page = page,
                .pages = pages,
                .state = state,
                .user_data_opt = user_data,
            });
        }
    }.f;
}

const HandlerFunc = fn (
    Context,
    *http.Response,
    http.Request,
    Data,
) anyerror!void;

pub const Data = struct {
    board: []const u8,
    page: u16,
};
