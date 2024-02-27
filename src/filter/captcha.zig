const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const model = root.model;
const handler = root.handler;
const filter = root.filter;
const util = handler.util;

const Context = root.Context;

const Error = filter.Error;

pub fn post(
    context: Context,
    _: *http.Response,
    request: http.Request,
) !void {
    const user_opt = try handler.util.getUserOpt(context, request);
    defer root.util.free(context.alloc, user_opt);

    const user_data = try model.user.info(context, user_opt, null);
    const flags = model.user.flags(user_data);
    if (flags.atLeastGlobalMod()) return;

    var form = try request.form(context.alloc);
    defer form.deinit(context.alloc);

    const opt = handler.util.nullIfEmpty(form.fields.get("captcha"));

    if (!try model.captcha.match(context, request.address, opt)) {
        return Error.WrongCaptcha;
    }
}
