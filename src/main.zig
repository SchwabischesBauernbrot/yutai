const std = @import("std");
const http = @import("apple_pie");
const sqlite = @import("sqlite");

pub const query = @import("query");

pub const c = @import("c.zig");
pub const util = @import("util.zig");
pub const data = @import("data/data.zig");
pub const view = @import("view/view.zig");
//pub const query = @import("query/query.zig");
pub const model = @import("model/model.zig");
pub const filter = @import("filter/filter.zig");
pub const handler = @import("handler/handler.zig");

pub const routes = @import("routes.zig").routes;

pub const Config = @import("config.zig");
pub const Context = @import("context.zig");
pub const Address = @import("address.zig").Address;
pub const Statements = @import("statements.zig");

pub const Server = http.Server(
    Context,
    http.router.Router(Context, &routes),
    handler.err.handle,
);

var server_ptr: *Server = undefined;

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }){};
    defer std.debug.assert(gpa.deinit() != .leak);

    const alloc = gpa.allocator();

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const arena_alloc = arena.allocator();

    const seed = @as(u64, @bitCast(std.time.timestamp()));
    var rng_gen = std.rand.DefaultPrng.init(seed);
    var rng = rng_gen.random();

    c.MagickWandGenesis();
    defer c.MagickWandTerminus();

    var config = try Config.init(arena_alloc, "config.json");

    var db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = "data.db" },
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .Serialized,
    });
    defer db.deinit();

    _ = try db.pragma(void, .{}, "foreign_keys", "1");
    _ = try db.pragma(void, .{}, "recursive_triggers", "1");

    var statements = Statements.init(&db) catch |err| {
        std.log.debug("{}", .{db.getDetailedError()});
        return err;
    };
    defer statements.deinit();

    var cache = try Context.Cache.init(config.favicon);
    defer cache.deinit();

    const context = Context{
        .alloc = alloc,
        .rng = rng,
        .db = &db,
        .config = config,
        .statements = &statements.list,
        .cache = cache,
    };

    try http.FileServer.init(alloc, .{
        .dir_path = "static",
        .base_path = "static",
        .immutable = true,
    });
    defer http.FileServer.deinit();

    var http_opt: ?http.HttpData = if (config.http) |v|
        .{ .address = try std.net.Address.parseIp(v.ip, v.port) }
    else
        null;

    var https_opt: ?http.HttpsData = if (config.https) |v|
        .{
            .address = try std.net.Address.parseIp(v.ip, v.port),
            .cert_path = v.cert,
            .key_path = v.key,
        }
    else
        null;

    var server: Server = undefined;

    try server.init(alloc);
    defer server.deinit();

    server_ptr = &server;
    try installSignals();

    try server.run(http_opt, https_opt, context);
}

fn installSignals() !void {
    try installSignal(std.os.SIG.INT, sigintHandler);
    try installSignal(std.os.SIG.USR1, sigusr1Handler);
}

const SignalHandler = *const fn (c_int) callconv(.C) void;
fn installSignal(sig: u6, f: SignalHandler) !void {
    const act = std.os.Sigaction{
        .handler = .{ .handler = f },
        .mask = std.os.empty_sigset,
        .flags = 0,
    };

    try std.os.sigaction(sig, &act, null);
}

fn sigintHandler(_: c_int) callconv(.C) void {
    std.log.info("sigint handled", .{});
    server_ptr.shutdown();
}

fn sigusr1Handler(_: c_int) callconv(.C) void {}
