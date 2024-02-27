const std = @import("std");
const ztt = @import("lib/ztt/src/TemplateStep.zig");
const bearssl = @import("lib/zig-BearSSL/build.zig");

pub fn build(b: *std.build.Builder) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //defer std.debug.assert(!gpa.deinit());

    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "yutai",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = mode,
    });

    try addTemplates(gpa.allocator(), b, exe);

    addPackage(exe, "sqlite", "lib/zig-sqlite/sqlite.zig");
    addPackage(exe, "ctregex", "lib/ctregex/ctregex.zig");
    addPackage(exe, "apple_pie", "lib/apple_pie/src/apple_pie.zig");

    bearssl.link(b, exe, target, mode);

    exe.linkLibC();
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

fn addTemplates(
    alloc: std.mem.Allocator,
    b: *std.build.Builder,
    exe: *std.build.LibExeObjStep,
) !void {
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

        const name = try alloc.dupe(u8, path[0..name_len]);
        //defer alloc.free(name);

        var rel_path = try alloc.alloc(u8, template_path.len + path.len);
        //defer alloc.free(rel_path);

        std.mem.copy(u8, rel_path, template_path);
        std.mem.copy(u8, rel_path[template_path.len..], path);

        for (name) |*c| {
            if (c.* == '/') c.* = '_';
        }
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
