update post_image_rows_view set
    file_state = 2,
    file_moderator = ?
where address = ? and file_state < 2;
