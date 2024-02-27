select * from (
select *
from reply
    natural join post
    natural left join post_image_view
where thread = ? and board = ? and (? or removed = 0)
order by post desc
limit ?
) order by post asc;
