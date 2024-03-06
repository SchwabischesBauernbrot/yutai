select image.*
from post natural join post_image natural join image
where address = ? and file_state <= ?;
