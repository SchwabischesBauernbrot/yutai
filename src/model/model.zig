const std = @import("std");
const sqlite = @import("sqlite");
const root = @import("root");

pub const address = @import("address.zig");
pub const ban = @import("ban.zig");
pub const board = @import("board.zig");
pub const captcha = @import("captcha.zig");
pub const entry = @import("entry.zig");
pub const log = @import("log.zig");
pub const mod = @import("mod.zig");
pub const post_image = @import("post_image.zig");
pub const post = @import("post.zig");
pub const reply = @import("reply.zig");
pub const report = @import("report.zig");
pub const stats = @import("stats.zig");
pub const thread = @import("thread.zig");
pub const user = @import("user.zig");
pub const util = @import("util.zig");

pub const CError = error{
    MagickWandException,
    NotAnImage,
};

pub const DataError = error{
    NotFound,
    InvalidCredentials,
    UnknownAddress,
    ExistingBoard,
    ExistingUser,
    ExistingMod,
};

pub const Error = CError ||
    DataError ||
    sqlite.Error ||
    std.mem.Allocator.Error ||
    std.fs.Dir.DeleteFileError ||
    std.fs.File.OpenError ||
    std.fs.File.WriteError ||
    error{InvalidIPAddressFormat} ||
    error{Workaround};
