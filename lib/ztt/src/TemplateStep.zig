const std = @import("std");

const Self = @This();

step: std.build.Step,
builder: *std.build.Builder,
source: std.build.FileSource,

output_file: std.build.GeneratedFile,

pub fn create(builder: *std.build.Builder, file: []const u8) *Self {
    return createSource(builder, .{ .path = file });
}

pub fn createSource(builder: *std.build.Builder, source: std.build.FileSource) *Self {
    const self = builder.allocator.create(Self) catch unreachable;
    self.* = Self{
        .step = std.build.Step.init(.{
            .id = .custom,
            .name = "build-template",
            .owner = builder,
            .makeFn = make,
        }),
        .builder = builder,
        .source = source,

        .output_file = std.build.GeneratedFile{ .step = &self.step },
    };
    source.addStepDependencies(&self.step);
    return self;
}

pub fn transform(builder: *std.build.Builder, file: []const u8) std.build.FileSource {
    const step = create(builder, file);
    return step.getFileSource();
}

pub fn transformSource(builder: *std.build.Builder, source: std.build.FileSource) std.build.FileSource {
    const step = createSource(builder, source);
    return step.getFileSource();
}

/// Returns the file source
pub fn getFileSource(self: *const Self) std.build.FileSource {
    return std.build.FileSource{ .generated = &self.output_file };
}

fn make(step: *std.build.Step, _: *std.Progress.Node) !void {
    const self = @fieldParentPtr(Self, "step", step);

    const source_file_name = self.source.getPath(self.builder);

    // std.debug.print("source = '{s}'\n", .{source_file_name});

    const basename = std.fs.path.basename(source_file_name);

    const output_name = blk: {
        if (std.mem.indexOf(u8, basename, ".")) |index| {
            break :blk try std.mem.join(self.builder.allocator, ".", &[_][]const u8{
                basename[0..index],
                "zig",
            });
        } else {
            break :blk try std.mem.join(self.builder.allocator, ".", &[_][]const u8{
                basename,
                "zig",
            });
        }
    };

    // std.debug.print("basename = '{s}'\n", .{basename});
    // std.debug.print("output name = '{s}'\n", .{output_name});

    var output_buffer = std.ArrayList(u8).init(self.builder.allocator);
    defer output_buffer.deinit();

    {
        var file = try std.fs.cwd().openFile(source_file_name, .{});
        defer file.close();

        var buffered_reader = std.io.bufferedReader(file.reader());

        var reader = buffered_reader.reader();
        var writer = output_buffer.writer();

        const UnderlyingWriter = @TypeOf(writer);

        const Writer = struct {
            const W = @This();
            const State = enum { init, text, code, nvar, sstr, str, done };

            writer: UnderlyingWriter,
            state: State = .init,
            ws_last: bool = false,

            fn start(wr: *W) !void {
                std.debug.assert(wr.state == .init);
                try wr.writer.writeAll(
                    \\const std = @import("std");
                    \\const root = @import("root");
                    \\
                    \\const view = root.view;
                    \\const util = view.util;
                    \\const partial = view.partial;
                    \\
                    \\pub fn render(output: anytype, context: anytype) !void {
                    \\
                );
                wr.state = .code;
            }

            fn writeText(wr: *W, slice: []const u8) !void {
                switch (wr.state) {
                    .text => {},
                    .code => {
                        try wr.endCode();
                        try wr.beginText();
                    },
                    .nvar => {
                        try wr.endNVar();
                        try wr.beginText();
                    },
                    .sstr => {
                        try wr.endSStr();
                        try wr.beginText();
                    },
                    .str => {
                        try wr.endStr();
                        try wr.beginText();
                    },
                    else => unreachable,
                }
                wr.state = .text;

                for (slice) |c| {
                    switch (c) {
                        9...13 => {},
                        0...8, 14...31 => try wr.writer.print("\\x{X:0>2}", .{c}),
                        '\\', '\"', '\'' => {
                            try wr.writer.writeByte('\\');
                            try wr.writer.writeByte(c);
                        },
                        32 => {
                            if (!wr.ws_last) {
                                wr.ws_last = true;
                                try wr.writer.writeByte(c);
                            }
                        },
                        else => {
                            wr.ws_last = false;
                            try wr.writer.writeByte(c);
                        },
                    }
                }

                // try wr.writer.writeAll(slice);
            }

            fn writeNVar(wr: *W, slice: []const u8) !void {
                switch (wr.state) {
                    .nvar => {},
                    .text => {
                        try wr.endText();
                        try wr.beginNVar();
                    },
                    else => unreachable,
                }
                wr.state = .nvar;

                var iterator = slice;
                try wr.writer.writeAll(iterator);
            }

            fn writeSStr(wr: *W, slice: []const u8) !void {
                switch (wr.state) {
                    .sstr => {},
                    .text => {
                        try wr.endText();
                        try wr.beginSStr();
                    },
                    else => unreachable,
                }
                wr.state = .sstr;

                var iterator = slice;
                try wr.writer.writeAll(iterator);
            }

            fn writeStr(wr: *W, slice: []const u8) !void {
                switch (wr.state) {
                    .str => {},
                    .text => {
                        try wr.endText();
                        try wr.beginStr();
                    },
                    else => unreachable,
                }
                wr.state = .str;

                var iterator = slice;
                try wr.writer.writeAll(iterator);
            }

            fn writeCode(wr: *W, slice: []const u8) !void {
                switch (wr.state) {
                    .code => {},
                    .text => {
                        try wr.endText();
                        try wr.beginCode();
                    },
                    else => unreachable,
                }
                wr.state = .code;

                var iterator = slice;
                while (iterator.len > 0) {
                    if (std.mem.indexOf(u8, iterator, "\n")) |index| {
                        if (index > 0) {
                            try wr.writer.writeAll(iterator[0 .. index - 1]);
                        }
                        try wr.writer.writeAll("\n    ");
                        iterator = iterator[index + 1 ..];
                    } else {
                        try wr.writer.writeAll(iterator);
                        break;
                    }
                }
            }

            fn finalize(wr: *W) !void {
                switch (wr.state) {
                    .text => try wr.endText(),
                    .code => try wr.endCode(),
                    .nvar => try wr.endNVar(),
                    .sstr => try wr.endSStr(),
                    .str => try wr.endStr(),
                    else => unreachable,
                }
                try wr.writer.writeAll(
                    \\}
                    \\
                );
                wr.state = .done;
            }

            fn beginText(wr: *W) !void {
                wr.ws_last = false;
                try wr.writer.writeAll("    try output.writeAll(\"");
            }

            fn endText(wr: *W) !void {
                wr.ws_last = false;
                try wr.writer.writeAll("\");\n");
            }

            fn beginNVar(wr: *W) !void {
                try wr.writer.writeAll("    try output.print(\"{}\", .{");
            }
            fn endNVar(wr: *W) !void {
                try wr.writer.writeAll("});\n");
            }

            fn beginSStr(wr: *W) !void {
                try wr.writer.writeAll("    try util.sanitize(output, ");
            }
            fn endSStr(wr: *W) !void {
                try wr.writer.writeAll(");\n");
            }

            fn beginStr(wr: *W) !void {
                try wr.writer.writeAll("    try output.print(\"{s}\", .{");
            }
            fn endStr(wr: *W) !void {
                try wr.writer.writeAll("});\n");
            }

            fn beginCode(wr: *W) !void {
                try wr.writer.writeAll("    ");
            }
            fn endCode(wr: *W) !void {
                try wr.writer.writeAll("\n");
            }
        };

        var generator = Writer{ .writer = writer };

        try generator.start();

        var previous_char: u8 = 0;
        const Segment = enum { text, nvar, sstr, str, code };

        var segment: Segment = .text;
        var byte: u8 = 0;
        while (true) : (previous_char = byte) {
            byte = reader.readByte() catch |err| switch (err) {
                error.EndOfStream => break,
                else => |e| return e,
            };

            if (segment == .text) {
                if (byte == '<') continue;
                if (previous_char == '<') {
                    switch (byte) {
                        '?' => {
                            segment = .code;
                            byte = 0;
                            continue;
                        },
                        '[' => {
                            segment = .nvar;
                            continue;
                        },
                        '(' => {
                            segment = .sstr;
                            continue;
                        },
                        '{' => {
                            segment = .str;
                            continue;
                        },
                        else => try generator.writeText("<"),
                    }
                }
                try generator.writeText(&[_]u8{byte});
            } else {
                const end_char: u8 = switch (segment) {
                    .code => '?',
                    .nvar => ']',
                    .sstr => ')',
                    .str => '}',
                    else => unreachable,
                };
                const writeFunc = switch (segment) {
                    .code => &Writer.writeCode,
                    .nvar => &Writer.writeNVar,
                    .sstr => &Writer.writeSStr,
                    .str => &Writer.writeStr,
                    else => unreachable,
                };
                if ((previous_char == end_char) and (byte == '>')) {
                    segment = .text;
                    try generator.writeText("");
                } else if (byte == end_char) {
                    // skip the ? for now
                } else {
                    if (previous_char == '<' and (byte == 0))
                        try writeFunc(&generator, "<");
                    if (previous_char == end_char)
                        try writeFunc(&generator, &[_]u8{end_char});
                    try writeFunc(&generator, &[_]u8{byte});
                }
            }
        }

        try generator.finalize();
    }

    // std.debug.print("data = '{s}'\n", .{output_buffer.items});

    // The cache is used here not really as a way to speed things up - because writing
    // the data to a file would probably be very fast - but as a way to find a canonical
    // location to put build artifacts.

    // If, for example, a hard-coded path was used as the location to put WriteFileStep
    // files, then two WriteFileSteps executing in parallel might clobber each other.

    // TODO port the cache system from stage1 to zig std lib. Until then we use blake2b
    // directly and construct the path, and no "cache hit" detection happens; the files
    // are always written.
    var hash = std.crypto.hash.blake2.Blake2b384.init(.{});

    // Random bytes to make TemplateStep unique. Refresh this with
    // new random bytes when TemplateStep implementation is modified
    // in a non-backwards-compatible way.
    hash.update("C9XVU4MgSDFZz2to");

    hash.update(basename);
    hash.update(output_buffer.items);
    var digest: [48]u8 = undefined;
    hash.final(&digest);

    var hash_basename: [64]u8 = undefined;
    _ = std.fs.base64_encoder.encode(&hash_basename, &digest);
    const output_dir = try std.fs.path.join(self.builder.allocator, &[_][]const u8{
        self.builder.cache_root.path.?,
        "o",
        &hash_basename,
    });
    // std.debug.print("out dir = {s}\n", .{self.output_dir});

    var dir = std.fs.cwd().makeOpenPath(output_dir, .{}) catch |err| {
        std.debug.print("unable to make path {s}: {s}\n", .{ output_dir, @errorName(err) });
        return err;
    };

    self.output_file.path = try std.fs.path.join(self.builder.allocator, &[_][]const u8{
        output_dir,
        output_name,
    });

    // std.debug.print("out file = {s}\n", .{self.file_name});

    dir.writeFile(output_name, output_buffer.items) catch |err| {
        std.debug.print("unable to write {s} into {s}: {s}\n", .{
            output_name,
            output_dir,
            @errorName(err),
        });
        return err;
    };

    //std.debug.print("----------------------------------\n{s}\n----------------------------------\n", .{output_buffer.items});
}
