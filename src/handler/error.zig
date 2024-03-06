const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const view = root.view;
const model = root.model;
const handler = root.handler;
const filter = root.filter;
const util = handler.util;

const Context = root.Context;

pub fn handle(
    context: Context,
    response: *http.Response,
    request_opt: ?http.Request,
    err: anyerror,
) anyerror!void {
    if (response.empty()) {
        const user_opt = if (request_opt) |request|
            try util.getUserOpt(context, request)
        else
            null;
        defer root.util.free(context.alloc, user_opt);

        const user_data_opt = try model.user.info(context, user_opt, null);

        response.status_code = toStatus(err);
        try util.render(response, view.fail, .{
            .title = title(err),
            .message = "",
            .user_data_opt = user_data_opt,
            .config = context.config,
        });
    }
}

fn toStatus(err: anyerror) http.StatusCode {
    return switch (err) {
        http.Request.ParseError.HeadersTooLarge => .request_header_fields_too_large,
        http.Request.ParseError.ContentTooLarge => .request_entity_too_large,
        model.Error.InvalidCredentials => .forbidden,
        model.Error.UnknownAddress => .not_found,
        model.Error.MagickWandException => .internal_server_error,
        model.Error.ExistingBoard => .unprocessable_entity,
        model.Error.ExistingUser => .unprocessable_entity,
        model.Error.ExistingMod => .unprocessable_entity,
        handler.Error.NotFound => .not_found,
        handler.Error.InvalidForm => .unprocessable_entity,
        handler.Error.MissingFields => .bad_request,
        handler.Error.BadForm => .bad_request,
        filter.Error.WrongCaptcha => .unprocessable_entity,
        std.mem.Allocator.Error.OutOfMemory => .internal_server_error,
        std.fs.File.OpenError.FileNotFound => .not_found,
        else => .bad_request,
    };
}

fn title(err: anyerror) []const u8 {
    return switch (err) {
        model.Error.ExistingBoard => "Board url already in use",
        model.Error.ExistingUser => "User name already in use",
        model.Error.ExistingMod => "Already mod",
        filter.Error.WrongCaptcha => "Wrong Captcha",
        else => toStatus(err).toString(),
    };
}
