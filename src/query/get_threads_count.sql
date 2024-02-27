select count(thread.post)
from thread
    natural join post
where board = ? and (? or removed = 0);
