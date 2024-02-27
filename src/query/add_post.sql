insert into post (
    post,
    thread,
    board,
    date,
    subject,
    message,
    address,
    email,
    name
) values (?, ?, ?, unixepoch(), ?, ?, ?, ?, ?);
