select *
from user
where session = ? and session_expires > unixepoch();
