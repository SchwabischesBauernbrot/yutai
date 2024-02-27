update image set
    file_date = unixepoch(),
    file_state = 2,
    file_moderator = ?
where hash = ?;
