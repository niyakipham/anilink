#!/bin/bash

# Yêu cầu người dùng nhập URL cùng hàng với echo
echo -n "Nhập URL của trang web: "
read url

# Dùng curl để tải trang và trích xuất nội dung của thẻ <div id="video-player">
# Sau đó, sử dụng grep và sed để chỉ lấy link trong thuộc tính src
link=$(curl -s "$url" | sed -n '/<div id="video-player">/,/<\/div>/p' | grep -oP 'src="\K[^"]+')

# Kiểm tra nếu có link và in ra
if [ -n "$link" ]; then
  echo "Link Anime: $link"
else
  echo "Không tìm thấy link trong thuộc tính src."
fi
