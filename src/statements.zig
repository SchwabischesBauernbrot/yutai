const std = @import("std");
const root = @import("root");
const sqlite = @import("sqlite");

pub const List = StatementsList(root.query);

list: List,

pub fn init(db: *sqlite.Db) !@This() {
    var temp: @This() = undefined;
    inline for (std.meta.fields(List)) |info| {
        @field(temp.list, info.name) = try info.type.init(db);
    }
    return temp;
}

pub fn deinit(self: *@This()) void {
    inline for (std.meta.fields(List)) |info| {
        @field(self.list, info.name).deinit();
    }
}

fn StatementsList(comptime queries: anytype) type {
    const decls = @typeInfo(queries).Struct.decls;
    const StructField = std.builtin.Type.StructField;
    comptime var fields: [decls.len]StructField = undefined;

    inline for (decls, &fields) |decl, *field| {
        const name = decl.name;
        const query = @field(queries, name);
        const Type = Statement(query);
        field.* = .{
            .name = name,
            .type = Type,
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(Type),
        };
    }
    comptime var info = std.builtin.Type{
        .Struct = .{
            .layout = .Auto,
            .backing_integer = null,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    };
    return @Type(info);
}

fn Statement(comptime sql: []const u8) type {
    return struct {
        const q = sql;

        s: StatementType(q) = undefined,

        pub fn init(db: *sqlite.Db) !@This() {
            return .{ .s = try db.prepare(q) };
        }

        pub fn deinit(self: *@This()) void {
            self.s.deinit();
        }
    };
}

fn StatementType(comptime sql: []const u8) type {
    return sqlite.StatementType(.{}, sql);
}
