read -r -p "Nhập URL của trang thông tin phim: " main_url

if [[ -z "$main_url" ]]; then
  echo "Lỗi: URL không được để trống."
  exit 1
fi

read -r -p "Nhập tên file đầu ra (phải có .txt ở cuối): " output_file


if [[ ! "$output_file" =~ \.txt$ ]]; then
  echo "Lỗi: Tên file đầu ra phải kết thúc bằng .txt"
  exit 1
fi

main_page=$(curl -s "$main_url")

main_title=$(echo "$main_page" | sed -n 's/.*<h1 class="heading_movie">\([^<]*\)<\/h1>.*/\1/p')

if [[ -z "$main_title" ]]; then
  echo "Warning: Không tìm thấy tiêu đề chính trên trang: $main_url"
  main_title="Không tìm thấy tiêu đề"
fi

episode_links=$(echo "$main_page" |
  sed -n '/<div class="list-item-episode scroll-bar">/,/<\/div>/p' |
  grep -o '<a[^>]*href=['"'"'"][^'"'"'"]*['"'"'"][^>]*>' |
  sed -E 's/.*href=['"'"'"]([^'"'"'"]*)['"'"'"].*/\1/')

while IFS= read -r episode_link; do
  echo "Processing: $episode_link"

  episode_page=$(curl -s "$episode_link")

  video_url=$(echo "$episode_page" |
    sed -n '/<div id="video-player">/,/<\/div>/p' |
    grep -oP 'src="\K[^"]+')

  echo "Title: $main_title"
  echo "Video URL: $video_url"

  echo "$main_title: $video_url" >> "$output_file"
  echo "---" >> "$output_file"

  echo "---"
done <<< "$episode_links"

echo "Danh sách URL video đã được lưu vào file: $output_file"
