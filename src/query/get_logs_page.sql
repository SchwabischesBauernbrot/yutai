select *
from log
where board is ?
order by date desc
limit ? offset ?;
