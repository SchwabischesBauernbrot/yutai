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

pub fn get(context: Context, addr: std.net.Address) !data.Captcha {
    const q = "get_captcha";

    var buf: [64]u8 = undefined;
    const address = try util.bufAddressStr(&buf, addr);

    const opt = try util.oneAlloc(data.Captcha, context, q, .{address});
    if (opt) |captcha| {
        const date = std.time.timestamp();
        if (captcha.expires < date) {
            try deleteExpired(context);
            return try add(context, address);
        } else {
            return captcha;
        }
    } else {
        return try add(context, address);
    }
}

pub fn deleteExpired(context: Context) !void {
    const q = "get_expired_captchas";

    const captchas = try util.all(data.Captcha, context, q, .{});
    defer root.util.free(context.alloc, captchas);

    try util.beginTransaction(context);
    errdefer util.rollbackTransaction(context) catch {};

    for (captchas) |captcha| {
        try delete(context, captcha);
    }

    util.endTransaction(context) catch {};
}

pub fn match(
    context: Context,
    address: std.net.Address,
    opt: ?[]const u8,
) !bool {
    const captcha = try get(context, address);
    defer root.util.free(context.alloc, captcha);

    try delete(context, captcha);

    const input = opt orelse return false;
    return std.mem.eql(u8, captcha.code, input);
}

fn add(context: Context, address: []const u8) !data.Captcha {
    const rng = context.rng;
    const alloc = context.alloc;
    const config = context.config;
    const q = "add_captcha";

    const code_buf = try alloc.alloc(u8, config.captcha.code_length);
    const code = util.randStr(rng, code_buf);

    var name_buf: [10]u8 = undefined;
    const name = util.randStr(rng, &name_buf);

    const now = @as(usize, @intCast(std.time.timestamp()));
    const expires = now + config.captcha.duration;

    const path = try std.fmt.allocPrintZ(
        alloc,
        "static/captcha/{s}.jpg",
        .{name},
    );

    const captcha = data.Captcha{
        .address = try alloc.dupe(u8, address),
        .expires = expires,
        .code = code,
        .path = path,
    };

    try generate(alloc, rng, config.captcha.font, code, path);
    try util.exec(context, q, .{ address, expires, code, path });

    return captcha;
}

fn delete(context: Context, captcha: data.Captcha) !void {
    const q = "delete_captcha";
    try util.exec(context, q, .{captcha.address});
    try util.deleteFileZ(captcha.path);
}

fn generate(
    alloc: std.mem.Allocator,
    rng: std.rand.Random,
    font: [:0]const u8,
    str: []const u8,
    path: [:0]const u8,
) !void {
    const w = 200;
    const h = 70;
    const font_size = 50;

    const min_line_w = 10;
    const max_line_w = 20;

    const line_count = 5;

    const distort_limiter = w / 10;

    const min_distorts = 3;
    const max_distorts = 5;

    const base_distorts = [_]f64{ 0, 0, 0, 0, 0, h, 0, h, w, 0, w, 0, w, h, w, h };
    const base_distorts_count = base_distorts.len;

    const level = 1;

    var status: c.MagickBooleanType = undefined;
    var i: usize = undefined;

    const c_str = try alloc.dupeZ(u8, str);
    defer alloc.free(c_str);

    c.MagickWandGenesis();
    defer c.MagickWandTerminus();

    const white_pw = c.NewPixelWand();
    defer _ = c.DestroyPixelWand(white_pw);
    try setPixelWandColor(white_pw, "white");

    const black_pw = c.NewPixelWand();
    defer _ = c.DestroyPixelWand(black_pw);
    try setPixelWandColor(black_pw, "black");

    const text_dw = c.NewDrawingWand();
    defer _ = c.DestroyDrawingWand(text_dw);

    c.DrawSetFillColor(text_dw, black_pw);
    c.DrawSetFontSize(text_dw, font_size);
    c.DrawSetGravity(text_dw, c.CenterGravity);

    status = c.DrawSetFont(
        text_dw,
        font.ptr,
    );
    try check(text_dw, status);

    //text image
    const text_wand: ?*c.MagickWand = c.NewMagickWand();
    defer _ = c.DestroyMagickWand(text_wand);

    status = c.MagickNewImage(text_wand, w, h, white_pw);
    try check(text_wand, status);

    status = c.MagickSetImageGravity(text_wand, c.CenterGravity);
    try check(text_wand, status);

    status = c.MagickAnnotateImage(text_wand, text_dw, 0, 0, 0, c_str.ptr);
    try check(text_wand, status);

    //mask image
    const mask_wand: ?*c.MagickWand = c.NewMagickWand();
    defer _ = c.DestroyMagickWand(mask_wand);

    status = c.MagickNewImage(mask_wand, w, h, white_pw);
    try check(mask_wand, status);

    var offset: f64 = rand(rng, -max_line_w, max_line_w) / level;
    i = 0;
    while (i < line_count * level) : (i += 1) {
        var line_w: f64 = rand(rng, min_line_w, max_line_w) / level;
        c.DrawRectangle(text_dw, 0, offset, w, offset + line_w);
        offset += rand(rng, min_line_w, max_line_w) / level + line_w;
    }

    status = c.MagickDrawImage(mask_wand, text_dw);
    try check(mask_wand, status);

    //composite
    status = c.MagickCompositeImage(
        text_wand,
        mask_wand,
        c.DifferenceCompositeOp,
        c.MagickFalse,
        0,
        0,
    );
    try check(text_wand, status);

    status = c.MagickNegateImage(text_wand, c.MagickFalse);
    try check(text_wand, status);

    //distorts
    const count = rng.intRangeAtMostBiased(usize, min_distorts, max_distorts);
    const portion = w / @as(f64, @floatFromInt(count));

    const distorts = try alloc.alloc(f64, count * 4 + base_distorts.len);
    defer alloc.free(distorts);

    std.mem.copy(f64, distorts, &base_distorts);

    i = 0;
    while (i < count) : (i += 1) {
        const index = base_distorts_count + i * 4;
        const fi = @as(f64, @floatFromInt(i));
        const x = rand(rng, portion * fi, portion * (fi + 1));
        const y = rand(rng, 0, h);
        distorts[index + 0] = x;
        distorts[index + 1] = y;
        distorts[index + 2] = rand(rng, x - distort_limiter, x + distort_limiter);
        distorts[index + 3] = rand(rng, y - distort_limiter, y + distort_limiter);
    }

    status = c.MagickDistortImage(
        text_wand,
        c.ShepardsDistortion,
        distorts.len,
        distorts.ptr,
        c.MagickFalse,
    );
    try check(text_wand, status);

    status = c.MagickBlurImage(text_wand, 0, 1);
    try check(text_wand, status);

    status = c.MagickWriteImage(text_wand, path.ptr);
    try check(text_wand, status);
}

fn setPixelWandColor(pw: ?*c.PixelWand, str: [*c]const u8) !void {
    const status = c.PixelSetColor(pw, str);
    try check(pw, status);
}

fn check(wand: anytype, status: c.MagickBooleanType) !void {
    const Wand = @TypeOf(wand);
    if (status == c.MagickFalse) {
        var exception: c.ExceptionType = undefined;
        const err: [*c]const u8 = switch (Wand) {
            ?*c.MagickWand => c.MagickGetException(wand, &exception),
            ?*c.PixelWand => c.PixelGetException(wand, &exception),
            ?*c.DrawingWand => c.DrawGetException(wand, &exception),
            else => unreachable,
        };
        std.log.err("MagickWand error: {s}", .{err});
        return CError.MagickWandException;
    }
}

fn rand(rng: std.rand.Random, min: f64, max: f64) f64 {
    const offset = max - min;
    return rng.float(f64) * offset + min;
}
