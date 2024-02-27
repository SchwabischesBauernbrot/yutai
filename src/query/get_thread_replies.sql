select *
from reply
    natural join post
    natural left join post_image_view
where thread = ? and board = ? and (? or post.removed = 0)
order by post asc;
