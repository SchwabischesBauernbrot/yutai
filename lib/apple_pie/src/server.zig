//! Server handles the connection between the host and the clients.
//! After a client has succesfully connected, the server will ensure
//! the request is being parsed and handled correctly before dispatching
//! it to the user. The server also ensures a body is flushed to the client
//! before ending a cycle.

const std = @import("std");
const root = @import("root");

const Request = @import("Request.zig");
const resp = @import("response.zig");

const c = root.c;
const net = std.net;
const atomic = std.atomic;
const log = std.log.scoped(.apple_pie);
const Response = resp.Response;
const Allocator = std.mem.Allocator;
const Queue = atomic.Queue;

pub const Error = error{
    FailedContext,
    FailedHandshake,
    PemFileError,
    SSLError,
    SSLFDError,
};

pub const HttpData = struct {
    address: net.Address,
};

pub const HttpsData = struct {
    address: net.Address,
    cert_path: [:0]const u8,
    key_path: [:0]const u8,
};

pub fn RequestHandler(comptime Context: type) type {
    return fn (Context, *Response, Request) anyerror!void;
}

pub fn ErrorHandler(comptime Context: type) type {
    return fn (Context, *Response, ?Request, anyerror) anyerror!void;
}

const max_buffer_size = blk: {
    const given = if (@hasDecl(root, "buffer_size")) root.buffer_size else 1024 * 64; // 64kB
    break :blk @min(given, 1024 * 1024 * 16); // max stack size (16MB)
};

const max_request_size = blk: {
    const given = if (@hasDecl(root, "request_buffer_size")) root.request_buffer_size else 1024 * 64;
    break :blk @min(given, 1024 * 1024 * 16); // max stack size (16MB)
};

pub fn Server(
    comptime Context: type,
    comptime handler: RequestHandler(Context),
    comptime errorHandler: ErrorHandler(Context),
) type {
    return struct {
        pub const Handler = @TypeOf(handler);
        pub const Client = ClientFn(Context, handler, errorHandler);
        pub const Connections = std.AutoHashMap(*Client, void);

        should_quit: atomic.Atomic(bool),
        pool: std.Thread.Pool,
        alloc: std.mem.Allocator,
        clients: Queue(*Client),
        connections: Connections,

        pub fn init(self: *@This(), alloc: std.mem.Allocator) !void {
            self.should_quit = atomic.Atomic(bool).init(false);
            self.alloc = alloc;
            self.clients = Queue(*Client).init();
            self.connections = Connections.init(alloc);
            try self.pool.init(.{ .allocator = alloc });
        }

        pub fn deinit(self: *@This()) void {
            var iter = self.connections.keyIterator();
            while (iter.next()) |connection| {
                connection.*.stream.shutdown() catch |err| {
                    log.debug(
                        "A shutdown error occured: '{s}'",
                        .{@errorName(err)},
                    );
                };
                connection.*.stream.close();
            }
            self.connections.deinit();
            self.pool.deinit();
            while (self.clients.get()) |node| {
                self.alloc.destroy(node.data);
            }
            log.info("server down", .{});
        }

        pub fn run(
            self: *@This(),
            http_opt: ?HttpData,
            https_opt: ?HttpsData,
            context: Context,
        ) !void {
            const options = .{ .reuse_address = true };

            //HTTP-----------------

            var http_stream_opt: ?net.StreamServer =
                if (http_opt) |http|
            blk: {
                var stream = net.StreamServer.init(options);
                try stream.listen(http.address);
                break :blk stream;
            } else null;
            defer if (http_stream_opt) |*http_stream| http_stream.deinit();

            const http_pollfd = std.os.pollfd{
                .fd = if (http_stream_opt) |http_stream|
                    http_stream.sockfd.?
                else
                    -1,
                .events = std.os.POLL.IN,
                .revents = 0,
            };

            //HTTPS----------------

            var ssl_ctx: ?*c.SSL_CTX = null;
            defer if (ssl_ctx) |ctx| c.SSL_CTX_free(ctx);

            var https_stream_opt: ?net.StreamServer =
                if (https_opt) |https|
            blk: {
                ssl_ctx = try createContext(https);
                var stream = net.StreamServer.init(options);
                try stream.listen(https.address);
                break :blk stream;
            } else null;
            defer if (https_stream_opt) |*https_stream| https_stream.deinit();

            const https_pollfd = std.os.pollfd{
                .fd = if (https_stream_opt) |https_stream|
                    https_stream.sockfd.?
                else
                    -1,
                .events = std.os.POLL.IN,
                .revents = 0,
            };

            //POLL

            var fds = [_]std.os.pollfd{ http_pollfd, https_pollfd };
            const timespec = std.os.timespec{
                .tv_sec = context.config.ppoll_timeout,
                .tv_nsec = 0,
            };

            log.info("server up", .{});

            while (!self.should_quit.load(.SeqCst)) {
                const count: usize = std.os.ppoll(&fds, &timespec, null) catch |err|
                    switch (err) {
                    std.os.PPollError.SignalInterrupt => 0,
                    else => return err,
                };

                while (self.clients.get()) |node| {
                    const data = node.data;
                    data.stream.close();
                    self.alloc.destroy(data);
                    _ = self.connections.remove(data);
                }

                if (count == 0) continue;
                if (fds[0].revents & std.os.POLL.IN != 0) {
                    const http_stream = &http_stream_opt.?;
                    if (accept(http_stream)) |connection| {
                        try self.runClient(connection, context);
                    }
                }
                if (fds[1].revents & std.os.POLL.IN != 0) {
                    const https_stream = &https_stream_opt.?;
                    if (accept(https_stream)) |connection| {
                        try self.runTlsClient(ssl_ctx.?, connection, context);
                    }
                }
            }
        }

        pub fn shutdown(self: *@This()) void {
            self.should_quit.store(true, .SeqCst);
        }

        fn runClient(
            self: *@This(),
            connection: net.StreamServer.Connection,
            context: anytype,
        ) !void {
            const client = try self.alloc.create(Client);
            try self.connections.put(client, {});

            client.stream = .{ .plain = connection.stream };
            client.address = connection.address;
            client.node = .{ .data = client };
            try self.pool.spawn(Client.run, .{
                client,
                self.alloc,
                &self.clients,
                context,
            });
        }

        fn runTlsClient(
            self: *@This(),
            ssl_ctx: *c.SSL_CTX,
            connection: net.StreamServer.Connection,
            context: anytype,
        ) !void {
            const client = try self.alloc.create(Client);
            try self.connections.put(client, {});

            client.stream = .{ .secure = undefined };
            client.address = connection.address;
            client.node = .{ .data = client };
            try self.pool.spawn(Client.runTls, .{
                client,
                self.alloc,
                &self.clients,
                context,
                ssl_ctx,
                connection.stream,
            });
        }

        fn accept(server: *net.StreamServer) ?net.StreamServer.Connection {
            return server.accept() catch |err| blk: {
                log.debug("Could not accept connection: '{s}'", .{
                    @errorName(err),
                });
                break :blk null;
            };
        }
    };
}

fn ClientFn(
    comptime Context: type,
    comptime handler: RequestHandler(Context),
    comptime errorHandler: ErrorHandler(Context),
) type {
    return struct {
        const Self = @This();

        stream: Stream,
        address: net.Address = undefined,
        node: Queue(*Self).Node,

        fn run(
            self: *Self,
            gpa: Allocator,
            clients: *Queue(*Self),
            context: Context,
        ) void {
            self.handle(gpa, clients, context) catch |err| {
                log.err(
                    "An error occured with the connection: '{s}'",
                    .{@errorName(err)},
                );
                //if (@errorReturnTrace()) |trace| {
                //    std.debug.dumpStackTrace(trace.*);
                //}
            };
            signalClientEnd();
        }

        fn runTls(
            self: *Self,
            gpa: Allocator,
            clients: *Queue(*Self),
            context: Context,
            ssl_ctx: *c.SSL_CTX,
            stream: net.Stream,
        ) void {
            self.stream.secure.init(stream, ssl_ctx) catch |err| {
                log.err(
                    "An error occured with the handshake: '{s}'",
                    .{@errorName(err)},
                );
                printSSLError();
                signalClientEnd();
                return;
            };
            self.run(gpa, clients, context);
        }

        fn handle(self: *Self, gpa: Allocator, clients: *Queue(*Self), context: Context) !void {
            defer clients.put(&self.node);

            const max_length = context.config.max_request_length;

            var arena = std.heap.ArenaAllocator.init(gpa);
            defer arena.deinit();

            var stack_allocator = std.heap.stackFallback(max_buffer_size, arena.allocator());
            const stack_ally = stack_allocator.get();

            var buffer: [max_request_size]u8 = undefined;
            var buffered_reader = std.io.bufferedReader(
                self.stream.reader(),
            );

            while (true) {
                var body = std.ArrayList(u8).init(stack_ally);
                defer body.deinit();

                var response = Response{
                    .headers = resp.Headers.init(stack_ally),
                    .buffered_writer = std.io.bufferedWriter(self.stream.writer()),
                    .is_flushed = false,
                    .body = body.writer(),
                    .close = false,
                };

                var parsed_request = Request.parse(
                    stack_allocator.get(),
                    .{ .max_length = max_length },
                    buffered_reader.reader(),
                    &buffer,
                ) catch |err| {
                    log.debug(
                        "An error occured parsing the request: '{s}'",
                        .{@errorName(err)},
                    );
                    switch (err) {
                        error.InputOutput => return,
                        error.EndOfStream => return,
                        error.ConnectionResetByPeer => return,
                        else => {
                            try errorHandler(context, &response, null, err);
                            try response.flush();
                            continue;
                        },
                    }
                };
                parsed_request.address = self.address;
                logRequest(parsed_request);

                response.close =
                    parsed_request.context.connection_type == .close;

                handler(context, &response, parsed_request) catch |err| {
                    if (@errorReturnTrace()) |trace| {
                        std.debug.dumpStackTrace(trace.*);
                    }
                    log.debug(
                        "An error occured handling the request: '{s}'",
                        .{@errorName(err)},
                    );
                    try errorHandler(context, &response, parsed_request, err);
                };

                if (!response.is_flushed) try response.flush();

                if (response.close) return;
            }
        }
    };
}

pub const Stream = union(enum) {
    pub const ReadError = std.os.ReadError;
    pub const WriteError = std.os.WriteError;

    pub const Reader = std.io.Reader(*@This(), ReadError, read);
    pub const Writer = std.io.Writer(*@This(), WriteError, write);

    pub const Https = struct {
        stream: net.Stream,
        ctx: *c.SSL_CTX,
        ssl: *c.SSL,

        pub fn init(
            self: *@This(),
            stream: net.Stream,
            ctx: *c.SSL_CTX,
        ) !void {
            const ssl = c.SSL_new(ctx) orelse return error.SSLError;
            self.* = .{ .stream = stream, .ctx = ctx, .ssl = ssl };
            if (c.SSL_set_fd(self.ssl, self.stream.handle) <= 0)
                return error.SSLFDError;
            if (c.SSL_accept(self.ssl) <= 0) return error.FailedHandshake;
        }

        pub fn recv(self: *@This(), buf: []u8) ReadError!usize {
            const len = @as(c_int, @intCast(buf.len));
            const l = c.SSL_read(self.ssl, buf.ptr, len);
            return if (l < 0)
                ReadError.InputOutput
            else
                @as(usize, @intCast(l));
        }

        pub fn send(self: *@This(), buf: []const u8) WriteError!usize {
            const len = @as(c_int, @intCast(buf.len));
            const l = c.SSL_write(self.ssl, buf.ptr, len);
            return if (l < 0)
                WriteError.InputOutput
            else
                @as(usize, @intCast(l));
        }

        pub fn close(self: *@This()) void {
            _ = c.SSL_shutdown(self.ssl);
            c.SSL_free(self.ssl);
            self.stream.close();
        }
    };

    secure: Https,
    plain: net.Stream,

    pub fn reader(self: *@This()) Reader {
        return .{ .context = self };
    }

    pub fn writer(self: *@This()) Writer {
        return .{ .context = self };
    }

    pub fn read(self: *@This(), bytes: []u8) ReadError!usize {
        return switch (self.*) {
            .secure => |*stream| try stream.recv(bytes),
            .plain => |*stream| try stream.read(bytes),
        };
    }

    pub fn write(self: *@This(), bytes: []const u8) WriteError!usize {
        return switch (self.*) {
            .secure => |*stream| try stream.send(bytes),
            .plain => |*stream| try stream.write(bytes),
        };
    }

    pub fn close(self: *@This()) void {
        switch (self.*) {
            .secure => |*stream| stream.close(),
            .plain => |*stream| stream.close(),
        }
    }

    pub fn shutdown(self: *@This()) !void {
        try std.os.shutdown(self.handle(), .both);
    }

    fn handle(self: *@This()) std.os.socket_t {
        return switch (self.*) {
            .secure => |stream| stream.stream.handle,
            .plain => |stream| stream.handle,
        };
    }
};

fn createContext(https: HttpsData) !*c.SSL_CTX {
    const method = c.TLS_server_method();
    const ctx = c.SSL_CTX_new(method) orelse return error.FailedContext;

    if (c.SSL_CTX_use_certificate_file(
        ctx,
        https.cert_path.ptr,
        c.SSL_FILETYPE_PEM,
    ) <= 0) {
        printSSLError();
        return error.PemFileError;
    }

    if (c.SSL_CTX_use_PrivateKey_file(
        ctx,
        https.key_path.ptr,
        c.SSL_FILETYPE_PEM,
    ) <= 0) {
        printSSLError();
        return error.PemFileError;
    }

    return ctx;
}

fn printSSLError() void {
    const err = c.ERR_get_error();

    var buf: [128]u8 = undefined;
    const ptr = c.ERR_error_string(err, &buf);
    const str = std.mem.span(ptr);
    std.log.err("SSL Error: {s}", .{str});
}

fn signalClientEnd() void {
    std.os.kill(std.os.linux.getpid(), std.os.SIG.USR1) catch {};
}

fn logRequest(request: Request) void {
    var buf: [16]u8 = undefined;
    var stamp = std.time.timestamp();
    const gmt = c.gmtime(&stamp);
    const len = c.strftime(&buf, buf.len, "%d/%m/%y %R", gmt);
    const time = buf[0..len];

    log.info("[{s}] ({}): {s} {?s}", .{
        time,
        request.address,
        @tagName(request.context.method),
        request.context.uri.path,
    });
}
