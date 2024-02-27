select *
from ban
where expires between ? and ? and board is ?
order by date desc
limit ? offset ?;
