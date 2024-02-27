select *
from report
where closed between ? and ? and
    ((global = false and board is ?) or (global = true and ?))
order by date desc
limit ? offset ?;
