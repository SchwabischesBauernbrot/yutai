insert into report (
    board,
    thread,
    post,
    reason,
    date,
    address,
    global
) values (?, ?, ?, ?, unixepoch(), ?, ?);
