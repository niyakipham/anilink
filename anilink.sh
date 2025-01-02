  GNU nano 8.2                                                          ani.sh                                                                    
read -r -p "Nhập URL của trang thông tin phim: " main_url

# Kiểm tra xem URL có hợp lệ hay không (có thể thêm kiểm tra nâng cao hơn)
if [[ -z "$main_url" ]]; then
  echo "Lỗi: URL không được để trống."
  exit 1
fi

# Yêu cầu người dùng nhập tên file đầu ra
read -r -p "Nhập tên file đầu ra (phải có .txt ở cuối): " output_file

# Kiểm tra xem tên file đầu ra có hợp lệ hay không
if [[ ! "$output_file" =~ \.txt$ ]]; then
  echo "Lỗi: Tên file đầu ra phải kết thúc bằng .txt"
  exit 1
fi

# Tải nội dung trang thông tin phim, trích xuất các link tập phim
episode_links=$(curl -s "$main_url" |
  sed -n '/<div class="list-item-episode scroll-bar">/,/<\/div>/p' |
  grep -o '<a[^>]*href=['"'"'"][^'"'"'"]*['"'"'"][^>]*>' |
  sed -E 's/.*href=['"'"'"]([^'"'"'"]*)['"'"'"].*/\1/')

# Lặp qua từng link tập phim
while IFS= read -r episode_link; do
  echo "Processing: $episode_link"

  # Tải nội dung trang tập phim, trích xuất URL video
  video_url=$(curl -s "$episode_link" |
    sed -n '/<div id="video-player">/,/<\/div>/p' |
    grep -oP 'src="\K[^"]+')

  # Hiển thị URL video
  echo "Video URL: $video_url"

  # Lưu URL video và dấu phân cách vào file
  echo "Video URL: $video_url" >> "$output_file"
  echo "---" >> "$output_file"

  echo "---"
done <<< "$episode_links"

echo "Danh sách URL video đã được lưu vào file: $output_file"
