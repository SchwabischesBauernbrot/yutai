select *
from thread
    natural join post
    natural left join post_image_view
where post = ? and board = ? and (? or post.removed = 0);
