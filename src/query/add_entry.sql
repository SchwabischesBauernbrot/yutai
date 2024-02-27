insert into entry (
    subject,
    body,
    date,
    name
) values (?, ?, unixepoch(), ?);
