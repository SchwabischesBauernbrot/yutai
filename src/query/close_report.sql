update report set
    closed = unixepoch(),
    message = ?,
    moderator = ?
where report_id = ? and (board is ? or (global = true and ? = true));
