select *
from ban
where (expires > unixepoch() or expires = 0)
    and (board is ? or board is null)
    and address = ?;
