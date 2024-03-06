update post_image_rows_view set
    image_moderator = $moderator
where address = $address and
    ($board is null or board = $board);
