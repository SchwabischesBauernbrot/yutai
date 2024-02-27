const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const handler = root.handler;
const filter = root.filter;

const Context = root.Context;
const Route = http.router.Route(Context);
const Handler = Route.Handler;
const Filter = Route.Filter;

pub const routes = .{
    publicGet("/static/*", serveStatic),
    publicGet("/captcha", handler.captcha.get),
    publicGet("/favicon.ico", handler.favicon.get),

    //global home
    publicGet("/", handler.global.index.get),
    globalModPost("/", handler.global.index.post),

    //global ban
    globalModGet("/ban/:address", handler.global.ban.get),
    globalModPost("/ban/:address", handler.global.ban.post),

    //global reports
    globalModPost("/reports/close", handler.global.reports.post),
    globalModGet("/reports/all/:page", handler.global.reports.all),
    globalModGet("/reports/open/:page", handler.global.reports.open),
    globalModGet("/reports/closed/:page", handler.global.reports.closed),

    //global bans
    globalModGet("/bans/dismiss/:ban_id", handler.global.bans.post),
    globalModGet("/bans/all/:page", handler.global.bans.all),
    globalModGet("/bans/expired/:page", handler.global.bans.expired),
    globalModGet("/bans/temporary/:page", handler.global.bans.temporary),
    globalModGet("/bans/permanent/:page", handler.global.bans.permanent),

    //global logs
    globalModGet("/logs/:page", handler.global.logs.get),

    //global mod
    globalModGet("/mod", handler.global.mod.get),
    globalModPost("/mod/addMod", handler.global.mod.addMod),
    globalModGet("/mod/removeMod/:name", handler.global.mod.removeMod),
    globalModPost("/mod/addBoard", handler.global.mod.addBoard),
    globalModGet("/mod/removeBoard/:name", handler.global.mod.removeBoard),

    //image (global mod)
    globalModGet("/mod/eraseImage/:hash", handler.global.image.erase),

    //image (global_mod)
    globalModGet("/mod/banImage/:hash", handler.global.image.ban),

    //user
    userGet("/user", handler.user.index.get),
    userPost("/user/update/pass", handler.user.index.pass),
    publicGet("/user/login", handler.user.login.get),
    globalPost("/user/login", handler.user.login.post),
    publicGet("/user/register", handler.user.register.get),
    globalPost("/user/register", handler.user.register.post),
    userGet("/user/logout", handler.user.logout.post),

    //post
    publicPost("/:board/post/report", handler.post.report.post),
    publicPost("/:board/post/delete", handler.post.delete.delete),

    //post (mod)
    modPost("/:board/mod/post/delete", handler.post.delete.modDelete),
    globalModPost("/:board/global/post/delete", handler.post.delete.globalModDelete),

    //post_image (mod)
    modGet("/:board/mod/image/delete/:id", handler.post.image.delete),

    //board mod
    modGet("/:board/mod", handler.board.mod.get),
    modPost("/:board/update/name", handler.board.mod.name),
    modPost("/:board/update/description", handler.board.mod.description),
    modPost("/:board/mod/add", handler.board.mod.add),
    modGet("/:board/mod/remove/:name", handler.board.mod.remove),

    //board ban
    modGet("/:board/ban/:address", handler.board.ban.get),
    modPost("/:board/ban/:address", handler.board.ban.post),

    //board reports
    modPost("/:board/reports/close", handler.board.reports.post),
    modGet("/:board/reports/all/:page", handler.board.reports.all),
    modGet("/:board/reports/open/:page", handler.board.reports.open),
    modGet("/:board/reports/closed/:page", handler.board.reports.closed),

    //board bans
    modGet("/:board/bans/dismiss/:ban_id", handler.board.bans.post),
    modGet("/:board/bans/all/:page", handler.board.bans.all),
    modGet("/:board/bans/expired/:page", handler.board.bans.expired),
    modGet("/:board/bans/temporary/:page", handler.board.bans.temporary),
    modGet("/:board/bans/permanent/:page", handler.board.bans.permanent),

    //board logs
    modGet("/:board/logs/:page", handler.board.logs.get),

    //thread (mod)
    modGet("/:board/sticky/:thread", handler.post.sticky.sticky),
    modGet("/:board/unsticky/:thread", handler.post.sticky.unsticky),

    //thread
    publicGet("/:board/res/:thread", handler.board.thread.get),
    publicFilePost("/:board/res/:thread", handler.board.thread.post),

    //board
    publicGet("/:board/catalog", handler.board.catalog.get),

    //board
    publicGet("/:board", handler.board.index.redirect),
    publicGet("/:board/:page", handler.board.index.get),
    publicFilePost("/:board/", handler.board.index.post),
};

const publicGet = autoFilter(.get, .{});
const publicPost = autoFilter(.post, post_filters);
const publicFilePost = autoFilter(.post, file_filters);
const globalPost = autoFilter(.post, global_post_filters);
const userGet = autoFilter(.get, user_filters);
const userPost = autoFilter(.post, user_post_filters);
const modGet = autoFilter(.get, mod_filters);
const modPost = autoFilter(.post, mod_post_filters);
const ownerPost = autoFilter(.post, owner_post_filters);
const globalModGet = autoFilter(.get, global_mod_filters);
const globalModPost = autoFilter(.post, global_mod_filters);
const RootPost = autoFilter(.post, root_filters);

const global_post_filters = .{
    filter.ban.global,
    filter.captcha.post,
};

const post_filters = .{filter.ban.local} ++ global_post_filters;
const file_filters = post_filters ++ .{filter.image.post};

const user_filters = .{filter.user.isUser};
const mod_filters = .{filter.user.atLeastMod};
const owner_filters = .{filter.user.atLeastOwner};

const global_mod_filters = .{filter.user.atLeastGlobalMod};
const root_filters = .{filter.user.atLeastRoot};

const user_post_filters = global_post_filters ++ user_filters;
const mod_post_filters = post_filters ++ mod_filters;
const owner_post_filters = post_filters ++ owner_filters;

const AutoFilter = fn (comptime []const u8, comptime anytype) Route;
fn autoFilter(
    comptime method: http.Request.Method,
    comptime fs: anytype,
) AutoFilter {
    return struct {
        pub fn f(comptime path: []const u8, comptime hs: anytype) Route {
            return filteredRoute(method, path, fs, hs);
        }
    }.f;
}

fn route(
    comptime method: http.Request.Method,
    comptime path: []const u8,
    comptime hs: anytype,
) Route {
    return filteredRoute(method, path, &.{}, hs);
}

fn filteredRoute(
    comptime method: http.Request.Method,
    comptime path: []const u8,
    comptime fs: anytype,
    comptime hs: anytype,
) Route {
    var filters: [fs.len]*const Filter = undefined;
    for (fs, 0..) |f, i| {
        filters[i] = &wrapper(f);
    }
    return .{
        .method = method,
        .path = path,
        .capture_type = CaptureType(hs),
        .filters = &filters,
        .handler = wrapper(hs),
    };
}

fn wrapper(comptime func: anytype) Handler {
    return struct {
        pub fn f(
            context: Context,
            response: *http.Response,
            request: http.Request,
            captures: ?*const anyopaque,
        ) anyerror!void {
            return if (CaptureType(func)) |Data| blk: {
                const d = toData(Data, captures);
                break :blk func(context, response, request, d);
            } else func(context, response, request);
        }
    }.f;
}

fn toData(comptime Data: type, ptr: ?*const anyopaque) Data {
    const Aligned = ?*align(@alignOf(*const Data)) const anyopaque;
    const aligned: Aligned = @alignCast(ptr);
    return @as(
        *const Data,
        @ptrCast(aligned),
    ).*;
}

fn CaptureType(comptime func: anytype) ?type {
    const Type = @TypeOf(func);
    const info = @typeInfo(Type).Fn;
    return if (info.params.len >= 4) info.params[3].type else null;
}

fn serveStatic(
    _: Context,
    response: *http.Response,
    request: http.Request,
) !void {
    try http.FileServer.serve({}, response, request);
}
