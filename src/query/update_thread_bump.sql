with args as (select ? as board, ? as thread)
update thread
set last_reply = ?
where post = (select thread from args) and
    board = (select board from args) and
    (
        select replies
        from thread_reply_count_view
        where post = (select thread from args) and
            board = (select board from args)
    ) < ?;
