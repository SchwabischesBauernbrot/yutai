const std = @import("std");

pub fn Join(comptime A: type, comptime B: type) type {
    const StructField = std.builtin.Type.StructField;
    const a_fields = std.meta.fields(A);
    const b_fields = std.meta.fields(B);
    comptime var fields: [a_fields.len + b_fields.len]StructField = undefined;
    comptime var len: usize = 0;

    inline for (a_fields) |field| {
        fields[len] = field;
        len += 1;
    }

    const map = std.ComptimeStringMap(void, fieldNameList(A));
    inline for (b_fields) |field| {
        if (!map.has(field.name)) {
            fields[len] = field;
            len += 1;
        }
    }

    comptime var info = std.builtin.Type{
        .Struct = .{
            .layout = .Auto,
            .backing_integer = null,
            .fields = fields[0..len],
            .decls = &.{},
            .is_tuple = false,
        },
    };
    return @Type(info);
}

pub fn LeftJoin(comptime A: type, comptime B: type) type {
    const StructField = std.builtin.Type.StructField;
    const a_fields = std.meta.fields(A);
    const b_fields = std.meta.fields(B);
    comptime var fields: [a_fields.len + b_fields.len]StructField = undefined;
    comptime var len: usize = 0;

    inline for (a_fields) |field| {
        fields[len] = field;
        len += 1;
    }

    const map = std.ComptimeStringMap(void, fieldNameList(A));
    inline for (b_fields) |field| {
        if (!map.has(field.name)) {
            const Type = Optional(field.type);
            fields[len] = .{
                .name = field.name,
                .type = Type,
                .default_value = null,
                .is_comptime = false,
                .alignment = @alignOf(Type),
            };
            len += 1;
        }
    }

    comptime var info = std.builtin.Type{
        .Struct = .{
            .layout = .Auto,
            .backing_integer = null,
            .fields = fields[0..len],
            .decls = &.{},
            .is_tuple = false,
        },
    };
    return @Type(info);
}

const Tuple = std.meta.Tuple(&.{[]const u8});
fn fieldNameList(comptime Type: type) []Tuple {
    const fields = std.meta.fields(Type);
    comptime var buf: [fields.len]Tuple = undefined;
    inline for (fields, &buf) |field, *item| {
        item.@"0" = field.name;
    }
    return &buf;
}

fn Optional(comptime Type: type) type {
    return if (@typeInfo(Type) == .Optional)
        Type
    else
        ?Type;
}
