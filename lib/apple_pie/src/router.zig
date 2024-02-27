//! Comptime Trie based router that creates a Trie
//! for each HTTP method and a catch-all one that works
//! on any method, granted it has a handler defined.
//! The router parses params into a type defined as the 3rd
//! argument of the handler function. Any other argument is ignored for parsing.
//! multi-params require a struct as argument type.

const std = @import("std");
const trie = @import("trie.zig");
const Request = @import("Request.zig");
const Response = @import("response.zig").Response;
const RequestHandler = @import("server.zig").RequestHandler;

/// Route defines the path, method and how to parse such path
/// into a type that the handler can accept.
pub fn Route(comptime Context: type) type {
    return struct {
        pub const Handler = fn (Context, *Response, Request, ?*const anyopaque) anyerror!void;
        pub const Filter = Handler;
        /// Path by which the route is triggered
        path: []const u8,
        /// The type the path captures will be transformed into
        /// This type will be passed as an '*const anyopaque' as the final argument
        /// to the route handler.
        capture_type: ?type = null,
        filters: []*const Filter = &.{},
        /// The handler function that will be called when triggered
        handler: Handler,
        /// http method
        method: Request.Method,
    };
}

/// Generic function that inserts each route's path into a radix tree
/// to retrieve the right route when a request has been made
pub fn Router(comptime Context: type, comptime routes: []const Route(Context)) RequestHandler(Context) {
    @setEvalBranchQuota(20000);
    comptime var trees: [10]trie.Trie(u8) = undefined;
    inline for (&trees) |*t| t.* = trie.Trie(u8){};

    inline for (routes, 0..) |r, i| {
        if (@typeInfo(@TypeOf(r.handler)) != .Fn) @compileError("Handler must be a function");

        const args = @typeInfo(@TypeOf(r.handler)).Fn.params;

        if (args.len < 3) {
            @compileError("Handler must have atleast 3 arguments");
        }
        if (args[0].type.? != Context) {
            @compileError("Expected type '" ++ @typeName(Context) ++ "', but found type '" ++ @typeName(args[0].type.?) ++ "'");
        }
        if (args[1].type.? != *Response) {
            @compileError("Second parameter must be of type " ++ @typeName(*Response));
        }
        if (args[2].type.? != Request) {
            @compileError("Third parameter must be of type " ++ @typeName(Request));
        }

        trees[@intFromEnum(r.method)].insert(r.path, i);
    }

    return struct {
        const Self = @This();

        fn handle(comptime route: Route(Context), params: []const trie.Entry, ctx: Context, res: *Response, req: Request) !void {
            var pa: ?*const anyopaque = null;
            if (route.capture_type) |ArgType| {
                const param: ArgType = switch (ArgType) {
                    []const u8 => if (params.len > 0) params[0].value else &[_]u8{},
                    ?[]const u8 => if (params.len > 0) params[0].value else null,
                    else => switch (@typeInfo(ArgType)) {
                        .Struct => |info| blk: {
                            var new_struct: ArgType = undefined;
                            inline for (info.fields) |field| {
                                for (params) |p| {
                                    if (std.mem.eql(u8, field.name, p.key)) {
                                        const FieldType = @TypeOf(@field(new_struct, field.name));

                                        @field(new_struct, field.name) = switch (FieldType) {
                                            []const u8, ?[]const u8 => p.value,
                                            else => switch (@typeInfo(FieldType)) {
                                                .Int => std.fmt.parseInt(FieldType, p.value, 10) catch 0,
                                                .Optional => |opt| if (@typeInfo(opt.child) == .Int)
                                                    std.fmt.parseInt(opt.child, p.value, 10) catch null
                                                else
                                                    @compileError("Unsupported optional type " ++ @typeName(opt.child)),
                                                else => @compileError("Unsupported type " ++ @typeName(FieldType)),
                                            },
                                        };
                                    }
                                }
                            }
                            break :blk new_struct;
                        },
                        .Int => std.fmt.parseInt(ArgType, params[0].value, 10) catch 0,
                        .Optional => |child| if (@typeInfo(child) == .Int)
                            std.fmt.parseInt(ArgType, params[0].value, 10) catch null
                        else
                            @compileError("Unsupported optional type " ++ @typeName(child)),
                        else => @compileError("Unsupported type " ++ @typeName(ArgType)),
                    },
                };
                pa = @as(?*const anyopaque, @ptrCast(&param));
            }
            for (route.filters) |filter| {
                try filter(ctx, res, req, pa);
            }
            try route.handler(ctx, res, req, pa);
        }

        pub fn serve(context: Context, response: *Response, request: Request) anyerror!void {
            switch (trees[@intFromEnum(request.method())].get(request.path())) {
                .none => {
                    // if nothing was found for current method, try the wildcard
                    switch (trees[9].get(request.path())) {
                        .none => return response.notFound(),
                        .static => |index| {
                            inline for (routes, 0..) |route, i|
                                if (index == i) return Self.handle(
                                    route,
                                    &.{},
                                    context,
                                    response,
                                    request,
                                );
                        },
                        .with_params => |object| {
                            inline for (routes, 0..) |route, i| {
                                if (object.data == i)
                                    return Self.handle(
                                        route,
                                        object.params[0..object.param_count],
                                        context,
                                        response,
                                        request,
                                    );
                            }
                        },
                    }
                },
                .static => |index| {
                    inline for (routes, 0..) |route, i| {
                        if (index == i) return Self.handle(
                            route,
                            &.{},
                            context,
                            response,
                            request,
                        );
                    }
                },
                .with_params => |object| {
                    inline for (routes, 0..) |route, i| {
                        if (object.data == i)
                            return Self.handle(
                                route,
                                object.params[0..object.param_count],
                                context,
                                response,
                                request,
                            );
                    }
                },
            }
        }
    }.serve;
}

/// Creates a builder namespace, generic over the given `Context`
/// This makes it easy to create the routers without having to passing
/// a lot of the types.
pub fn Builder(comptime Context: type) type {
    return struct {
        /// The generic handler type that all routes must match
        pub const HandlerType = fn (Context, *Response, Request, ?*const anyopaque) anyerror!void;
        pub const FilterType = HandlerType;

        /// Creates a new `Route` for the given HTTP Method that will be
        /// triggered based on its path conditions
        ///
        /// When the path contains parameters such as ':<name>' it will be captured
        /// and parsed into the type given as `capture_type`.
        pub fn basicRoute(
            comptime method: Request.Method,
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return .{
                .method = method,
                .path = path,
                .capture_type = CaptureType,
                .filters = filters,
                .handler = handler,
            };
        }

        /// Shorthand function to create a `Route` where method is 'GET'
        pub fn get(
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return basicRoute(.get, path, CaptureType, filters, handler);
        }
        /// Shorthand function to create a `Route` where method is 'POST'
        pub fn post(
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return basicRoute(.post, path, CaptureType, filters, handler);
        }
        /// Shorthand function to create a `Route` where method is 'PATCH'
        pub fn patch(
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return basicRoute(.patch, path, CaptureType, filters, handler);
        }
        /// Shorthand function to create a `Route` where method is 'PUT'
        pub fn put(
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return basicRoute(.put, path, CaptureType, filters, handler);
        }
        /// Shorthand function to create a `Route` which matches with any method
        pub fn any(
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return basicRoute(.any, path, CaptureType, filters, handler);
        }
        /// Shorthand function to create a `Route` where method is 'HEAD'
        pub fn head(
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return basicRoute(.head, path, CaptureType, filters, handler);
        }
        /// Shorthand function to create a `Route` where method is 'DELETE'
        pub fn delete(
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return basicRoute(.delete, path, CaptureType, filters, handler);
        }
        /// Shorthand function to create a `Route` where method is 'CONNECT'
        pub fn connect(
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return basicRoute(.connect, path, CaptureType, filters, handler);
        }
        /// Shorthand function to create a `Route` where method is 'OPTIONS'
        pub fn options(
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return basicRoute(.options, path, CaptureType, filters, handler);
        }
        /// Shorthand function to create a `Route` where method is 'TRACE'
        pub fn trace(
            comptime path: []const u8,
            comptime CaptureType: ?type,
            comptime filters: []*const FilterType,
            comptime handler: HandlerType,
        ) Route(Context) {
            return basicRoute(.trace, path, CaptureType, filters, handler);
        }
    };
}

test {
    std.testing.refAllDecls(@This());
}
