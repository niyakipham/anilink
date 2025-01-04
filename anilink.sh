#!/bin/bash

read -r -p "Nhập URL của trang thông tin phim: " main_url

if [[ -z "$main_url" ]]; then
  echo "Lỗi: URL không được để trống."
  exit 1
fi

read -r -p "Nhập tên file đầu ra (phải có .csv ở cuối): " output_file

if [[ ! "$output_file" =~ \.csv$ ]]; then
  echo "Lỗi: Tên file đầu ra phải kết thúc bằng .csv"
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

episode_titles=$(echo "$main_page" | awk '
/<div class="list-item-episode scroll-bar">/ { in_desired_div = 1 }
/<\/div>/ { in_desired_div = 0 }
in_desired_div && /<span>/ {
  gsub(/<[^>]*>/, "", $0);
  gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0);
  print
}
')

# In tiêu đề cột vào file CSV
echo "Title,Episode,URL" > "$output_file"

paste <(echo "$episode_titles") <(echo "$episode_links") | while IFS=$'\t' read -r episode_title episode_link; do
  echo "Processing: $episode_link"

  episode_page=$(curl -s "$episode_link")

  video_url=$(echo "$episode_page" |
    sed -n '/<div id="video-player">/,/<\/div>/p' |
    grep -oP 'src="\K[^"]+')
    
  if [[ -z "$video_url" ]]; then
    echo "Warning: Không tìm thấy URL video cho tập: $episode_title"
    video_url="Không tìm thấy URL"
  fi


  escaped_main_title=$(echo "$main_title" | sed 's/"/""/g')
  escaped_episode_title=$(echo "$episode_title" | sed 's/"/""/g')
  echo "\"$escaped_main_title\",\"$escaped_episode_title\",\"$video_url\"" >> "$output_file"

  echo "---"
done

echo "Danh sách URL video đã được lưu vào file: $output_file"
