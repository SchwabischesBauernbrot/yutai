select address
from post natural join post_image_view
where hash = ?;
