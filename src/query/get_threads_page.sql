--select *
--from thread
--    natural join post
--    natural left join post_image_view
--where board = 1
--    and post in (
--        select *
--        from thread natural join post
--        where (2 or post.removed = 0)
--        order by thread.last_reply desc
--        limit 3 offset 4
--    )
--order by thread.last_reply desc;
select *
from thread
    natural join post
    natural left join post_image_view
where board = ? and (? or post.removed = 0)
order by sticky desc, last_reply desc
limit ? offset ?
