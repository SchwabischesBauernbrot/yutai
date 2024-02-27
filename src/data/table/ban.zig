ban_id: usize,
board: ?[]const u8,
address: []const u8,
date: usize,
expires: usize,
reason: []const u8,
moderator: []const u8,

pub fn permanent(self: *const @This()) bool {
    return self.expires == 0;
}

pub fn expired(self: *const @This(), date: i64) bool {
    return self.expires <= date and !self.permanent();
}
