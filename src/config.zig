const std = @import("std");

const util = @import("util.zig");

pub const Http = struct {
    ip: []const u8,
    port: u16,
};

pub const Https = struct {
    ip: []const u8,
    port: u16,
    cert: [:0]const u8,
    key: [:0]const u8,
};

pub const Captcha = struct {
    font: [:0]const u8,
    duration: usize,
    code_length: usize,
};

http: ?Http,
https: ?Https,
max_request_length: usize,

icon: ?[]const u8,
favicon: ?[]const u8,
title: []const u8,
subtitle: []const u8,
banner: ?[]const u8,
snippet_length: usize,

ppoll_timeout: i64,

no_file_thumbnail: []const u8,
default_file_thumbnail: []const u8,
deleted_file_thumbnail: []const u8,

page_length: u16,
bump_limit: usize,
reply_count: usize,
board_pages: usize,
max_latest_posts: usize,
max_latest_images: usize,

thumbnail_size: usize,
default_name: []const u8,
address_salt: []const u8,

root_user: []const u8,

captcha: Captcha,

pub fn init(alloc: std.mem.Allocator, path: []const u8) !@This() {
    @setEvalBranchQuota(10000);
    const file = try util.readFileAlloc(alloc, path);
    return try std.json.parseFromSliceLeaky(@This(), alloc, file, .{});
}

pub fn threadLimit(self: *const @This()) usize {
    return self.page_length * self.board_pages;
}
