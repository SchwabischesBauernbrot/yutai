update image set
    file_date = unixepoch(),
    file_state = 1,
    file_moderator = ?
where hash = ? and file_state = 0;
