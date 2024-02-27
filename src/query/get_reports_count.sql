select count(report_id)
from report
where closed between ? and ? and
    ((global = false and board is ?) or (global = true and ?));
