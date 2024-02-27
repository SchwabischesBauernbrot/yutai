update post set
    removed = unixepoch(),
    reason = ?,
    moderator = ?
where post = ? and board = ?;
