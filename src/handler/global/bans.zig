const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const view = root.view;
const model = root.model;
const handler = root.handler;
const util = handler.util;

const Context = root.Context;

pub fn post(
    context: Context,
    response: *http.Response,
    request: http.Request,
    ban_id: usize,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    try model.ban.dismiss(context, user, "dismissed", null, ban_id);

    try util.message(response, "Global Ban(s) Dismissed!");
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
            page_arg: i64,
        ) anyerror!void {
            const page = try util.getPage(@as(i32, @intCast(page_arg)));
            const pages = model.ban.pages(context, null, state);
            try util.checkPage(page, pages);

            const bans = try model.ban.page(context, null, state, page);
            defer root.util.free(context.alloc, bans);

            const user_opt = try util.getUserOpt(context, request);
            defer root.util.free(context.alloc, user_opt);

            const user_data = try model.user.info(context, user_opt, null);

            try util.render(response, view.global.bans, .{
                .bans = bans,
                .page = page,
                .pages = pages,
                .state = state,
                .user_data_opt = user_data,
                .config = context.config,
            });
        }
    }.f;
}

const HandlerFunc = fn (
    Context,
    *http.Response,
    http.Request,
    i64,
) anyerror!void;
