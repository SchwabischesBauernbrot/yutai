const std = @import("std");
const root = @import("root");
const http = @import("apple_pie");

const handler = root.handler;

const Context = root.Context;

const RequestError = handler.RequestError;

pub fn get(
    context: Context,
    response: *http.Response,
    _: http.Request,
) !void {
    const header = "Cache-Control";
    const value = "max-age=604800";
    try response.headers.put(header, value);

    if (context.cache.favicon_opt) |favicon| {
        try http.FileServer.serveFile(response, "favicon.ico", favicon);
    }
}
