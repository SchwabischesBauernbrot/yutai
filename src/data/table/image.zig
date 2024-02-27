pub const State = enum(u8) {
    pub const BaseType = u8;
    none = 0,
    removed = 1,
    banned = 2,
};

hash: []const u8,
ext: []const u8,
width: ?usize,
height: ?usize,
thumb_width: ?usize,
thumb_height: ?usize,
size: usize,
refs: usize,
file_date: usize,
file_state: State,
file_moderator: []const u8,
