update ban set
    expires = unixepoch(),
    reason = ?,
    moderator = ?
where ban_id = ? and board is ?;
