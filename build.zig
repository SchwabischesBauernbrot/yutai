const std = @import("std");
const ztt = @import("lib/ztt/src/TemplateStep.zig");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "yutai",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = mode,
    });

    try addTemplates(b, exe);
    try embedQueries(b, exe);

    addPackage(exe, "sqlite", "lib/zig-sqlite/sqlite.zig");
    addPackage(exe, "ctregex", "lib/ctregex/ctregex.zig");
    addPackage(exe, "apple_pie", "lib/apple_pie/src/apple_pie.zig");

    exe.linkLibC();
    exe.linkSystemLibrary("openssl");
    exe.linkSystemLibrary("sqlite3");
    exe.linkSystemLibrary("MagickWand");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn addTemplates(
    b: *std.build.Builder,
    exe: *std.build.LibExeObjStep,
) !void {
    const alloc = b.allocator;
    const template_extension = ".html";
    const template_path = "src/view/";

    const cwd = std.fs.cwd();

    var dir = try cwd.openIterableDir(template_path, .{});
    defer dir.close();

    var walker = try dir.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        const path = entry.path;
        const name_len = path.len - template_extension.len;
        const extension = path[name_len..];
        if (!std.mem.eql(u8, template_extension, extension)) continue;

        const rel_path = try std.fs.path.join(
            alloc,
            &.{ template_path, path },
        );

        const name = try alloc.dupe(u8, path[0..name_len]);
        std.mem.replaceScalar(u8, name, '/', '_');

        addTemplateStep(b, exe, rel_path, name);
    }
}

fn addTemplateStep(
    b: *std.build.Builder,
    exe: *std.build.LibExeObjStep,
    path: []const u8,
    name: []const u8,
) void {
    const template_step = ztt.create(b, path);
    addPackageLazy(exe, name, template_step.getFileSource());
}

const QueriesStep = struct {
    b: *std.build.Builder,
    step: std.build.Step,
    file: std.build.GeneratedFile,

    pub fn getFileSource(self: *const @This()) std.build.FileSource {
        return .{ .generated = &self.file };
    }
};

fn embedQueries(
    b: *std.build.Builder,
    exe: *std.build.LibExeObjStep,
) !void {
    const alloc = b.allocator;
    const queries_step = try alloc.create(QueriesStep);

    queries_step.* = .{
        .b = b,
        .step = std.build.Step.init(.{
            .id = .custom,
            .name = "embed-queries",
            .owner = b,
            .makeFn = makeQueries,
        }),
        .file = .{ .step = &queries_step.step },
    };

    addPackageLazy(exe, "query", queries_step.getFileSource());
}

fn makeQueries(step: *std.build.Step, _: *std.Progress.Node) !void {
    const queries_step = @fieldParentPtr(QueriesStep, "step", step);
    const b = queries_step.b;
    const alloc = b.allocator;

    const output_name = "query.zig";
    const output_dir = try std.fs.path.join(
        alloc,
        &.{ b.cache_root.path.?, "q" },
    );

    var cwd = std.fs.cwd();
    cwd.deleteTree(output_dir) catch {};

    var dir = try std.fs.cwd().makeOpenPath(output_dir, .{});
    queries_step.file.path = try std.fs.path.join(
        alloc,
        &.{ output_dir, output_name },
    );

    const str = try generateFile(b, &dir);
    defer alloc.free(str);

    try dir.writeFile(output_name, str);
}

fn generateFile(b: *std.build.Builder, out_dir: *std.fs.Dir) ![]const u8 {
    const alloc = b.allocator;
    const query_ext = ".sql";
    const query_path = "src/query";

    var buf = std.ArrayList(u8).init(alloc);
    defer buf.deinit();

    var writer = buf.writer();

    const cwd = std.fs.cwd();

    var dir = try cwd.openIterableDir(query_path, .{});
    defer dir.close();

    var walker = try dir.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;

        const path = entry.path;
        const name = path[0 .. path.len - query_ext.len];
        const ext = path[name.len..];
        if (!std.mem.eql(u8, query_ext, ext)) continue;

        const rpath = try std.fs.path.join(
            alloc,
            &.{ b.build_root.path.?, query_path, path },
        );
        defer alloc.free(rpath);

        try writer.print(
            "pub const {s} = @embedFile(\"{s}\");\n",
            .{ name, path },
        );

        out_dir.deleteFile(path) catch {};
        try out_dir.symLink(rpath, path, .{});
    }

    return try buf.toOwnedSlice();
}

fn addPackage(
    exe: *std.build.CompileStep,
    name: []const u8,
    path: []const u8,
) void {
    addPackageLazy(exe, name, .{ .path = path });
}

fn addPackageLazy(
    exe: *std.build.CompileStep,
    name: []const u8,
    path: std.Build.LazyPath,
) void {
    exe.addAnonymousModule(name, .{ .source_file = path });
}
