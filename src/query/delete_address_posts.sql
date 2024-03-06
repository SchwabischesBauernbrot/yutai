update post set
    removed = unixepoch(),
    reason = $reason,
    moderator = $moderator
where address = $address and
    ($board is null or board = $board);
