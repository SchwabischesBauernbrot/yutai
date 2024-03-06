update thread
set last_reply = $post
where post = $thread and board = $board and
    (
        select replies
        from thread_reply_count_view
        where post = $thread and board = $board
    ) < $bump_limit;
