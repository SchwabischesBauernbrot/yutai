const std = @import("std");
const root = @import("root");

const model = root.model;
const handler = root.handler;

pub const user = @import("user.zig");
pub const ban = @import("ban.zig");
pub const captcha = @import("captcha.zig");
pub const image = @import("image.zig");

pub const RequestError = error{
    InvalidCredentials,
    WrongCaptcha,
    BannedImage,
    BannedAddress,
};

pub const Error = RequestError ||
    handler.Error;
