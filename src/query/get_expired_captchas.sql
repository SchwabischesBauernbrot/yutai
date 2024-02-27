select *
from captcha
where expires < unixepoch();
