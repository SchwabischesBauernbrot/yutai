insert into log (
    board,
    date,
    message
) values (?, unixepoch(), ?);
