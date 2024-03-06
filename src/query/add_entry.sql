insert into entry (
    subject,
    body,
    html,
    date,
    name
) values (?, ?, ?, unixepoch(), ?);
