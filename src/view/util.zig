const std = @import("std");
const root = @import("root");

const c = root.c;

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

pub fn writePostText(output: anytype, str: []const u8) !void {
    var itr = std.mem.splitScalar(u8, str, '\n');
    while (itr.next()) |line| {
        if (line.len > 0) {
            const is_quote = line[0] == '>' and refLen(line) == null;
            if (is_quote)
                try output.writeAll("<span class=\"quote\">");
            try writePostLine(output, line);
            if (is_quote)
                try output.writeAll("</span>");
        }
        if (itr.peek() != null) try output.writeAll("<br>");
    }
}

fn replacement(codepoint: anytype) ?[]const u8 {
    if (@typeInfo(@TypeOf(codepoint)) != .Int)
        @compileError("codepoint must be an integer");
    return switch (codepoint) {
        '>' => "&gt;",
        '<' => "&lt;",
        '&' => "&amp;",
        '"' => "&quot;",
        '\n' => "<br>",
        else => null,
    };
}

fn writePostLine(output: anytype, line: []const u8) !void {
    var spoiler: Range = .{};
    var italics: Range = .{};
    var bold: Range = .{};

    const formats = .{
        Format.init("[spoiler]", "[/spoiler]", &spoiler, "<span class=\"spoiler\">", "</span>"),
        Format.init("[i]", "[/i]", &italics, "<em>", "</em>"),
        Format.init("[b]", "[/b]", &bold, "<strong>", "</strong>"),
    };

    inline for (formats) |format| {
        format.update(line, 0);
    }

    var i: usize = 0;
    loop: while (i < line.len) {
        inline for (formats) |format| {
            if (try format.write(output, line, i)) |new_index| {
                i = new_index;
                continue :loop;
            }
        }

        const str = line[i..];
        if (refLen(str)) |ref_end| {
            try writeRef(output, str, ref_end);
            i += ref_end;
        } else {
            if (replacement(line[i])) |r| {
                try output.writeAll(r);
            } else {
                try output.writeByte(line[i]);
            }
            i += 1;
        }
    }
}

const Range = struct { begin_opt: ?usize = null, end_opt: ?usize = null };
const Format = struct {
    begin: []const u8,
    end: []const u8,
    state: *Range,
    begin_tag: []const u8,
    end_tag: []const u8,

    pub fn init(
        begin: []const u8,
        end: []const u8,
        state: *Range,
        begin_tag: []const u8,
        end_tag: []const u8,
    ) @This() {
        return .{
            .begin = begin,
            .end = end,
            .state = state,
            .begin_tag = begin_tag,
            .end_tag = end_tag,
        };
    }

    pub fn write(
        self: @This(),
        output: anytype,
        line: []const u8,
        index: usize,
    ) !?usize {
        if (self.state.end_opt) |end_pos| {
            var i = index;
            const active = self.state.begin_opt != null;
            if (end_pos == i) {
                i += self.end.len;
                self.update(line[i..], i);
                if (active) {
                    try output.writeAll(self.end_tag);
                    self.state.begin_opt = null;
                    return i;
                }
            } else if (!active and self.match(line[i..])) {
                self.state.begin_opt = i;
                try output.writeAll(self.begin_tag);
                i += self.begin.len;
                return i;
            }
        }
        return null;
    }

    fn update(self: @This(), str: []const u8, offset: usize) void {
        const opt = std.mem.indexOfPos(u8, str, self.begin.len, self.end);
        self.state.end_opt = if (opt) |pos| pos + offset else null;
    }

    fn match(self: @This(), str: []const u8) bool {
        return if (str.len >= self.begin.len)
            std.mem.eql(u8, str[0..self.begin.len], self.begin)
        else
            false;
    }
};

const ref_marker = ">>";

fn writeRef(output: anytype, str: []const u8, end: usize) !void {
    const ref = str[0..end];
    try output.print(
        "<a href=\"#{s}\">{s}</a>",
        .{ ref[ref_marker.len..], ref },
    );
}

fn refLen(str: []const u8) ?usize {
    if (str.len < 3) return null;
    if (!std.mem.eql(u8, str[0..2], ref_marker)) return null;
    var i: usize = 2;
    while (true) : (i += 1) {
        if (i == str.len) return i;
        const char = str[i];
        if (char == ' ') return if (i == ref_marker.len) null else i;
        if (char < '0' or char > '9') return null;
    }
}
