const std = @import("std");
const root = @import("root");
const ctregex = @import("ctregex");

const c = root.c;

fn replacement(codepoint: u21) ?[]const u8 {
    return switch (codepoint) {
        '>' => "&gt;",
        '<' => "&lt;",
        '&' => "&amp;",
        '"' => "&quot;",
        '\n' => "<br>",
        else => null,
    };
}

pub fn sanitize(writer: anytype, str: []const u8) !void {
    var view = try std.unicode.Utf8View.init(str);
    var iter = view.iterator();
    while (iter.nextCodepointSlice()) |slice| {
        const codepoint = try std.unicode.utf8Decode(slice);
        const src = if (replacement(codepoint)) |r| r else slice;
        try writer.writeAll(src);
    }
}

pub fn writePath(output: anytype, post: anytype) !void {
    if (post.thread) |thread| {
        try output.print(
            "/{s}/res/{}#{}",
            .{ post.board, thread, post.post },
        );
    } else {
        try output.print(
            "/{s}/res/{}",
            .{ post.board, post.post },
        );
    }
}

pub fn writeBody(output: anytype, post: anytype) !void {
    @setEvalBranchQuota(10000);
    const regex = ">>(\\d+)";
    const str = post.message;
    const board = post.board;
    const thread = post.thread orelse post.post;

    var index: usize = 0;
    while (try ctregex.search(regex, .{}, str[index..])) |match| {
        const slice = match.slice;
        const offset: usize = @intFromPtr(slice.ptr) - @intFromPtr(str.ptr);
        try sanitize(output, str[index..offset]);

        try output.print(
            "<a href=\"/{s}/res/{}#{s}\">",
            .{ board, thread, match.captures[0].? },
        );
        try sanitize(output, slice);
        try output.writeAll("</a>");

        index = offset + slice.len;
    } else {
        try sanitize(output, str[index..]);
    }
}

pub fn renderPost(
    output: anytype,
    context: anytype,
    template: anytype,
    rows: anytype,
    index: bool,
) !void {
    const thread = rows[0].thread orelse rows[0].post;
    try template.render(output, .{
        .thread = thread,
        .post_rows = rows,
        .index = index,
        .user_data_opt = context.user_data_opt,
        .board = context.board,
        .config = context.config,
    });
}

pub fn time(buff: []u8, stamp: usize) []const u8 {
    const gmt = c.gmtime(&@as(c_long, @intCast(stamp)));
    const len = c.strftime(buff.ptr, buff.len, "%d/%m/%y (%a) %R", gmt);
    return buff[0..len];
}

pub fn datetime(buff: []u8, stamp: usize) []const u8 {
    const gmt = c.gmtime(&@as(c_long, @intCast(stamp)));
    const len = c.strftime(buff.ptr, buff.len, "%FT%TZ", gmt);
    return buff[0..len];
}

pub fn sizeStr(buff: []u8, size: usize) ![]const u8 {
    const units = [_][]const u8{ "B", "KiB", "MiB", "GiB", "TiB" };
    const base = 0x400;
    const mask = base - 1;
    const shift = @as(usize, @log2(@as(f32, base)));

    var a = size;
    var r: usize = 0;
    var i: usize = 0;
    while (a > base and i < units.len) {
        r = a & mask;
        a = a >> shift;
        i += 1;
    }
    var x = @as(f32, @floatFromInt(a)) + @as(f32, @floatFromInt(r)) / base;

    const p: usize = if (r == 0) 0 else 2;
    return try std.fmt.bufPrint(buff, "{d:.[2]} {s}", .{ x, units[i], p });
}
