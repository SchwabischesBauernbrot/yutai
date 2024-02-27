insert into ban (
    board,
    address,
    date,
    expires,
    reason,
    moderator
) values (?, ?, unixepoch(), ?, ?, ?);
