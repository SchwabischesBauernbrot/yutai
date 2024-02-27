const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");
const ctregex = @import("ctregex");

const c = root.c;
const data = root.data;
const model = root.model;
const handler = root.handler;
const view = root.view;

const Context = root.Context;

const RequestError = handler.RequestError;
const Error = handler.Error;

pub fn setToken(
    response: *http.Response,
    session: []const u8,
    expires: i64,
) !void {
    var buf: [32]u8 = undefined;
    const date = rfc1123Date(&buf, expires);
    const cookie = try std.fmt.allocPrint(
        response.headers.allocator,
        "token={s}; Path=/; expires={s}",
        .{ session, date },
    );

    try response.headers.put("set-cookie", cookie);
}

pub fn removeToken(response: *http.Response) !void {
    const cookie = "token=; Path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT";

    try response.headers.put("set-cookie", cookie);
}

pub fn rfc1123Date(buf: []u8, stamp: i64) []const u8 {
    const gmt = c.gmtime(&@as(c_long, @intCast(stamp)));
    const fmtstr = "%a, %d %b %Y %T GMT";
    const len = c.strftime(buf.ptr, buf.len, fmtstr, gmt);
    return buf[0..len];
}

pub fn getField(form: http.Request.Form, field: []const u8) ![]const u8 {
    return form.fields.get(field) orelse RequestError.MissingFields;
}

pub fn getPage(page: i32) !u32 {
    const temp: i32 = page - 1;
    return if (temp < 0) RequestError.NotFound else @as(u32, @bitCast(temp));
}

pub fn getOptPage(page: ?i32) !u32 {
    return try getPage(page orelse 1);
}

pub fn checkPage(page: u32, pages: usize) !void {
    if (page >= pages) {
        return RequestError.NotFound;
    }
}

pub fn getUser(context: Context, request: http.Request) !data.User {
    var headers = try getHeaders(context.alloc, request);
    defer freeHeaders(context.alloc, &headers);

    const cookie = headers.get("Cookie") orelse
        return Error.InvalidCredentials;
    const token = getToken(cookie) orelse
        return Error.InvalidCredentials;

    return try model.user.fromSession(context, token.session);
}

pub fn getUserOpt(context: Context, request: http.Request) !?data.User {
    return getUser(context, request) catch |err| switch (err) {
        model.Error.InvalidCredentials => null,
        else => err,
    };
}

pub fn getHeaders(
    alloc: std.mem.Allocator,
    request: http.Request,
) !http.Request.Headers {
    return try request.headers(alloc);
}

pub fn freeHeaders(
    alloc: std.mem.Allocator,
    headers: *http.Request.Headers,
) void {
    var itr = headers.iterator();
    while (itr.next()) |pair| {
        alloc.free(pair.key_ptr.*);
        alloc.free(pair.value_ptr.*);
    }
    headers.deinit(alloc);
}

pub fn nullIfEmpty(arg: ?[]const u8) ?[]const u8 {
    return if (arg) |str| blk: {
        break :blk if (str.len == 0) null else str;
    } else null;
}

pub fn defaultIfEmpty(arg: ?[]const u8, default: []const u8) []const u8 {
    return if (arg) |str| blk: {
        break :blk if (str.len == 0) default else str;
    } else default;
}

pub fn render(response: *http.Response, v: anytype, d: anytype) !void {
    try response.headers.put("Cache-Control", "no-cache");
    try response.headers.put("Content-Type", "text/html");
    _ = try v.render(response.writer(), d);
}

pub fn redirect(
    status: http.StatusCode,
    response: *http.Response,
    comptime fmt: []const u8,
    d: anytype,
) !void {
    var url_buf: [0x200]u8 = undefined;
    var url = try std.fmt.bufPrint(&url_buf, fmt, d);
    try response.headers.put("Location", url);
    try response.writeHeader(status);
}

pub fn found(
    response: *http.Response,
    comptime fmt: []const u8,
    d: anytype,
) !void {
    return redirect(.found, response, fmt, d);
}

pub fn moved(
    response: *http.Response,
    comptime fmt: []const u8,
    d: anytype,
) !void {
    return redirect(.moved_permanently, response, fmt, d);
}

pub fn getPosts(
    alloc: std.mem.Allocator,
    map: http.Uri.KeyValueMap,
) ![][2][]const u8 {
    @setEvalBranchQuota(10000);

    var list = std.ArrayList([2][]const u8).init(alloc);
    defer list.deinit();

    const regex = "post_(\\d+)_(\\d+)";
    var itr = map.map.keyIterator();
    while (itr.next()) |key_ptr| {
        const key = key_ptr.*;
        const result_opt = try ctregex.match(regex, .{}, key);
        if (result_opt) |result| {
            if (result.captures[0]) |thread| {
                if (result.captures[1]) |p| {
                    try list.append(.{ thread, p });
                }
            }
        }
    }

    return list.toOwnedSlice();
}

pub fn getReports(
    alloc: std.mem.Allocator,
    map: http.Uri.KeyValueMap,
) ![][]const u8 {
    @setEvalBranchQuota(10000);

    var list = std.ArrayList([]const u8).init(alloc);
    defer list.deinit();

    const regex = "report_(\\d+)";
    var itr = map.map.keyIterator();
    while (itr.next()) |key_ptr| {
        const key = key_ptr.*;
        const result_opt = try ctregex.match(regex, .{}, key);
        if (result_opt) |result| {
            if (result.captures[0]) |capture| {
                try list.append(capture);
            }
        }
    }

    return list.toOwnedSlice();
}

pub fn getToken(
    cookie: []const u8,
) ?Token {
    @setEvalBranchQuota(10000);

    const regex = "token=([a-z]+)";
    const opt = ctregex.match(regex, .{}, cookie) catch null;
    if (opt) |result| {
        if (result.captures[0]) |session| {
            return Token{ .session = session };
        }
    }
    return null;
}

pub const Token = struct {
    session: []const u8,
};

pub fn message(response: *http.Response, title: []const u8) !void {
    try messageEx(response, title, "");
}

pub fn messageEx(
    response: *http.Response,
    title: []const u8,
    msg: []const u8,
) !void {
    try render(response, view.message, .{ .title = title, .message = msg });
}

pub fn errorView(response: *http.Response, title: []const u8) !void {
    try errorViewEx(response, title, "");
}

pub fn errorViewEx(
    response: *http.Response,
    title: []const u8,
    msg: []const u8,
) !void {
    try render(response, view.fail, .{ .title = title, .message = msg });
}

pub fn parseLength(str: []const u8) !i64 {
    @setEvalBranchQuota(10000);

    const s_per_m = 60;
    const s_per_h = s_per_m * 60;
    const s_per_d = s_per_h * 24;
    const s_per_w = s_per_d * 7;
    const s_per_M = s_per_d * 30;
    const seconds = [_]i64{
        s_per_M,
        s_per_w,
        s_per_d,
        s_per_h,
        s_per_m,
    };

    if (std.mem.eql(u8, str, "0")) return 0;

    //const regex = "^(?:(\\d+)M)?(?:(\\d+)w)?(?:(\\d+)d)?(?:(\\d+)h)?(?:(\\d+)m)?";
    const regex = "(\\d+M)?(\\d+w)?(\\d+d)?(\\d+h)?(\\d+m)?";
    const opt = ctregex.match(regex, .{}, str) catch null;
    return if (opt) |result| blk: {
        var total: i64 = 0;
        for (result.captures, 0..) |match_opt, i| {
            if (match_opt) |match| {
                const int_str = match[0 .. match.len - 1];
                const value = try std.fmt.parseInt(i64, int_str, 10);
                total += seconds[i] * value;
            }
        }
        break :blk total;
    } else error.InvalidForm;
}

pub fn parseRange(range_str: []const u8) !?root.Address.RangeSize {
    return if (std.mem.eql(u8, range_str, "single"))
        null
    else if (std.mem.eql(u8, range_str, "small"))
        .small
    else if (std.mem.eql(u8, range_str, "large"))
        .large
    else
        RequestError.InvalidForm;
}

pub fn getFiles(
    alloc: std.mem.Allocator,
    form: http.Request.Form,
) ![][2][]const u8 {
    var list = std.ArrayList([2][]const u8).init(alloc);
    defer list.deinit();

    if (nullIfEmpty(form.fields.get("file"))) |filename| {
        if (nullIfEmpty(form.files.get(filename))) |file| {
            try list.append(.{ filename, file });
        }
    }

    return list.toOwnedSlice();
}
