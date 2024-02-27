select *
from post
    natural join post_image_view
where image_removed = 0 and
    removed = 0 and
    file_state = 0 and
    thumb_width is not null
order by date desc
limit ?;
