select count(ban_id)
from ban
where expires between ? and ? and board is ?;
