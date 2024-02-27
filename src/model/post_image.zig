const std = @import("std");
const sqlite = @import("sqlite");
const root = @import("root");

const c = root.c;
const data = root.data;
const query = root.query;
const model = root.model;
const util = model.util;

const Context = root.Context;

const CError = model.CError;
const Error = model.Error;

const bufImagePath = util.bufImagePath;
const bufThumbnailPath = util.bufThumbnailPath;
const bufThumbnailPathZ = util.bufThumbnailPathZ;

pub fn add(
    context: Context,
    name: []const u8,
    file: []const u8,
    board: data.Board,
    post: usize,
) !void {
    const config = context.config;
    const thumbnail_size = config.thumbnail_size;

    var hash_buf: [128]u8 = undefined;
    const hash = util.md5(&hash_buf, file);
    const count_opt = try util.one(usize, context, "count_image", .{hash});
    const count = count_opt.?;

    if (count == 0) { //new image
        var extension = std.fs.path.extension(name);

        var image_buf: [128]u8 = undefined;
        const image_path = try bufImagePath(&image_buf, hash, extension);
        try saveFile(image_path, file);

        const image_data_opt: ?ImageData =
            saveThumbnail(hash, thumbnail_size, file) catch |err|
            if (err == CError.NotAnImage) null else return err;

        if (image_data_opt) |image_data| {
            try util.exec(context, "add_image", .{
                hash,
                extension,
                image_data.rect.w,
                image_data.rect.h,
                image_data.thumbnail_rect.w,
                image_data.thumbnail_rect.h,
                file.len,
            });
        } else {
            try util.exec(
                context,
                "add_image",
                .{ hash, extension, null, null, null, null, file.len },
            );
        }
    }

    try util.exec(
        context,
        "add_post_image",
        .{ hash, board.board, post, name },
    );
}

pub fn latest(context: Context) ![]data.PostImage {
    const config = context.config;
    const q = "get_latest_images";
    const limit = config.max_latest_images;
    return try util.all(data.PostImage, context, q, .{limit});
}

pub fn remove(context: Context, id: []const u8, user: data.User) !void {
    try util.exec(context, "delete_post_image", .{ user.name, id });
}

pub fn permanentRemove(
    context: Context,
    hash: []const u8,
    user: data.User,
) !void {
    const image = try get(context, hash);
    defer root.util.free(context.alloc, image);

    try util.exec(context, "delete_image", .{ user.name, hash });
    try erase(image.?);
}

pub fn ban(context: Context, hash: []const u8, user: data.User) !void {
    const image = try get(context, hash);
    defer root.util.free(context.alloc, image);

    try util.exec(context, "ban_image", .{ user.name, hash });
    try erase(image.?);

    const posters = try posted(context, hash);
    for (posters) |address| {
        try model.ban.addAddress(
            context,
            null,
            address,
            0,
            "banned image",
            user.name,
        );
    }
}

pub fn clear(context: Context) !void {
    try util.beginTransaction(context);
    const files = blk: {
        errdefer util.endTransaction(context) catch {};
        const tmp = try unused.all(context);
        try unused.clear(context);
        break :blk tmp;
    };
    defer root.util.free(context.alloc, files);
    util.endTransaction(context) catch {};

    for (files) |file| try erase(file);
}

fn posted(context: Context, hash: []const u8) ![][]const u8 {
    return try util.all([]const u8, context, "get_image_posters", .{hash});
}

pub fn get(context: Context, hash: []const u8) !?data.Image {
    return try util.oneAlloc(data.Image, context, "get_image", .{hash});
}

fn erase(file: data.Image) !void {
    if (file.file_state == .none) {
        var buf: [128]u8 = undefined;
        const path = try bufImagePath(&buf, file.hash, file.ext);
        try util.deleteFile(path);

        const tpath = try bufThumbnailPath(&buf, file.hash);
        try util.deleteFile(tpath);
    }
}

fn saveFile(path: []const u8, body: []const u8) !void {
    var file = try std.fs.cwd().createFile(path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close();

    _ = try file.writeAll(body);
}

fn saveThumbnail(
    hash: []const u8,
    size: usize,
    buff: []const u8,
) !ImageData {
    var path_buf: [128]u8 = undefined;
    const path = try bufThumbnailPathZ(&path_buf, hash);

    var status: c.MagickBooleanType = undefined;

    const wand: ?*c.MagickWand = c.NewMagickWand();
    defer _ = c.DestroyMagickWand(wand);

    status = c.MagickReadImageBlob(wand, buff.ptr, buff.len);
    if (status == c.MagickFalse) return CError.NotAnImage;

    var image_data: ImageData = undefined;

    c.MagickResetIterator(wand);
    while (c.MagickNextImage(wand) != c.MagickFalse) {
        const image = c.GetImageFromMagickWand(wand);
        image_data.rect = .{
            .w = image.*.columns,
            .h = image.*.rows,
        };
        image_data.thumbnail_rect = fitRect(image_data.rect, size);

        _ = c.MagickThumbnailImage(
            wand,
            image_data.thumbnail_rect.w,
            image_data.thumbnail_rect.h,
        );
    }

    status = c.MagickWriteImages(wand, path.ptr, c.MagickFalse);
    if (status == c.MagickFalse) return CError.MagickWandException;

    return image_data;
}

fn fitRect(rect: Rect, size: usize) Rect {
    var tmp = rect;
    if (tmp.w > size or tmp.h > size) {
        const i = tmp.h > tmp.w;
        if (i) swap(usize, &tmp.w, &tmp.h);
        const s = @as(f32, @floatFromInt(size));
        const r = @as(f32, @floatFromInt(tmp.h)) / @as(f32, @floatFromInt(tmp.w));
        tmp = .{ .w = size, .h = @as(usize, @intFromFloat(s * r)) };
        if (i) swap(usize, &tmp.w, &tmp.h);
    }
    return tmp;
}

fn swap(comptime T: type, a: *T, b: *T) void {
    const tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

const ImageData = struct {
    rect: Rect,
    thumbnail_rect: Rect,
};

const Rect = struct {
    w: usize,
    h: usize,
};

const unused = struct {
    pub fn all(context: Context) ![]data.Image {
        const q = "get_unused_images";
        return try util.all(data.Image, context, q, .{});
    }

    pub fn clear(context: Context) !void {
        try util.exec(context, "delete_unused_images", .{});
    }
};
