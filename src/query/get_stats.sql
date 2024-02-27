select * from
    (select count(post) as total_posts from post) join
    (select count(distinct address) as unique_posters from address) join
    (select sum(size) as content_size from image)
;
