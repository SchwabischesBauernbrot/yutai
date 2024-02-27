delete from thread
where post in (
    select post
    from thread
    where board = ?
    order by last_reply desc
    limit -1 offset ?
);
