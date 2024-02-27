insert into image (
    hash,
    ext,
    width,
    height,
    thumb_width,
    thumb_height,
    size
) values (?, ?, ?, ?, ?, ?, ?)
on conflict (hash) do nothing;
