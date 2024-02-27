select *
from ban
where address = ? and board is ?
order by expires desc;
