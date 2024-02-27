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
    board: []const u8,
) !void {
    const user = try util.getUser(context, request);
    defer root.util.free(context.alloc, user);

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const message = form.fields.get("message") orelse "";

    const reports = try util.getReports(context.alloc, form.fields);
    defer context.alloc.free(reports);

    try model.report.closeList(context, false, board, user, reports, message);

    try util.message(response, "Report(s) Closed!");
}

pub const all = reportsPage(.all);
pub const open = reportsPage(.open);
pub const closed = reportsPage(.closed);

fn reportsPage(
    comptime state: model.report.State,
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
            const pages = model.report.pages(context, false, args.board, state);
            try util.checkPage(page, pages);

            const reports = try model.report.page(
                context,
                false,
                args.board,
                state,
                page,
            );
            defer root.util.free(context.alloc, reports);

            const user_opt = try util.getUserOpt(context, request);
            defer root.util.free(context.alloc, user_opt);

            const user_data = try model.user.info(
                context,
                user_opt,
                args.board,
            );

            try util.render(response, view.reports, .{
                .reports = reports,
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
    page: i32,
};
