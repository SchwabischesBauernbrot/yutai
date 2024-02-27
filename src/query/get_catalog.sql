select *
from catalog_view
where board = ? and (? or removed = 0)
