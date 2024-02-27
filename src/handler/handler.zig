const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const model = root.model;

pub const global = struct {
    pub const mod = @import("global/mod.zig");
    pub const reports = @import("global/reports.zig");
    pub const index = @import("global/index.zig");
    pub const logs = @import("global/logs.zig");
    pub const bans = @import("global/bans.zig");
    pub const ban = @import("global/ban.zig");
    pub const image = @import("global/image.zig");
};

pub const board = struct {
    pub const mod = @import("board/mod.zig");
    pub const reports = @import("board/reports.zig");
    pub const index = @import("board/index.zig");
    pub const logs = @import("board/logs.zig");
    pub const bans = @import("board/bans.zig");
    pub const ban = @import("board/ban.zig");
    pub const thread = @import("board/thread.zig");
    pub const catalog = @import("board/catalog.zig");
};

pub const post = struct {
    pub const delete = @import("post/delete.zig");
    pub const report = @import("post/report.zig");
    pub const image = @import("post/image.zig");
    pub const sticky = @import("post/sticky.zig");
};

pub const user = struct {
    pub const index = @import("user/index.zig");
    pub const register = @import("user/register.zig");
    pub const login = @import("user/login.zig");
    pub const logout = @import("user/logout.zig");
};

pub const util = @import("util.zig");
pub const captcha = @import("captcha.zig");
pub const favicon = @import("favicon.zig");
pub const err = @import("error.zig");

pub const RequestError = error{
    NotFound,
    InvalidForm,
    MissingFields,
};

pub const Error = RequestError ||
    model.Error ||
    http.Request.FormError ||
    std.mem.Allocator.Error;
