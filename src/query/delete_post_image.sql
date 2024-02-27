update post_image set
    image_removed = unixepoch(),
    image_moderator = ?
where post_image_id = ?;
