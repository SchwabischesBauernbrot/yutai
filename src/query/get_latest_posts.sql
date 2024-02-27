select *
from post
where post.removed = 0
order by post.date desc
limit ?;
