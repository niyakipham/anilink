#!/bin/bash

# File chứa danh sách URL
url_file="data.txt"

# Kiểm tra xem file URL có tồn tại không
if [[ ! -f "$url_file" ]]; then
  echo "Lỗi: File URL '$url_file' không tồn tại."
  exit 1
fi

# Đặt tên file đầu ra cố định là anime.csv
output_file="anime.csv"
echo "Tên file đầu ra đã được đặt cố định là: $output_file"

# In tiêu đề cột vào file CSV (chỉ in một lần)
# Kiểm tra xem file có trống không HOẶC nếu có nội dung nhưng dòng đầu tiên không phải là tiêu đề
# Điều này để tránh ghi lại tiêu đề nếu file đã có và có định dạng đúng
first_line=$(head -n 1 "$output_file" 2>/dev/null)
if [[ ! -s "$output_file" || "$first_line" != "Title,Episode,URL" ]]; then
    echo "Title,Episode,URL" > "$output_file"
    echo "Đã ghi tiêu đề vào $output_file"
else
    echo "File $output_file đã có tiêu đề. Tiếp tục ghi dữ liệu."
fi


# Đọc từng URL từ file
while IFS= read -r main_url; do
  echo "Đang xử lý URL: $main_url"

  # Lấy nội dung trang chính
  main_page_content=$(curl -s "$main_url")
  if [[ -z "$main_page_content" ]]; then
    echo "Warning: Không thể lấy nội dung từ $main_url. Bỏ qua."
    continue
  fi

  # Lấy tiêu đề chính
  main_title=$(echo "$main_page_content" | sed -n 's/.*<h1 class="heading_movie">\([^<]*\)<\/h1>.*/\1/p' | head -n 1)

  if [[ -z "$main_title" ]]; then
    echo "Warning: Không tìm thấy tiêu đề chính trên trang: $main_url"
    main_title="Không tìm thấy tiêu đề"
  fi

  # Lấy danh sách link và tên tập
  episode_data=$(echo "$main_page_content" |
    # Tìm khối div chứa danh sách tập
    sed -n '/<div class="list-item-episode scroll-bar">/,/<\/div>/p' |
    # Trích xuất từng mục 'a' và xử lý
    awk '
    /<a / {
        # Lấy href
        match($0, /href="([^"]*)"/, href_arr)
        episode_link = href_arr[1]

        # Lấy tiêu đề tập từ thẻ span bên trong thẻ a
        match($0, /<span>([^<]*)<\/span>/, title_arr)
        episode_title = title_arr[1]

        # Xóa thẻ HTML và khoảng trắng thừa từ tiêu đề
        gsub(/<[^>]*>/, "", episode_title)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", episode_title)

        # In ra dưới dạng tab-separated
        if (episode_link != "" && episode_title != "") {
            print episode_title "\t" episode_link
        }
    }
    ')

  if [[ -z "$episode_data" ]]; then
      echo "Warning: Không tìm thấy thông tin tập phim nào cho $main_title tại $main_url"
      continue # Bỏ qua URL chính này nếu không có tập nào
  fi

  echo "$episode_data" | while IFS=$'\t' read -r episode_title episode_link; do
    if [[ -z "$episode_link" || -z "$episode_title" ]]; then
      echo "Warning: Dữ liệu tập bị thiếu, bỏ qua. Link: [$episode_link], Title: [$episode_title]"
      continue
    fi

    echo "Đang xử lý tập: \"$episode_title\" tại link: $episode_link"

    # Lấy nội dung trang của tập
    episode_page_content=$(curl -s "$episode_link")
    if [[ -z "$episode_page_content" ]]; then
      echo "Warning: Không thể lấy nội dung từ tập: $episode_title. Bỏ qua."
      continue
    fi

    # Lấy URL video
    # Đã điều chỉnh selector để chính xác hơn
    video_url=$(echo "$episode_page_content" |
      grep -oP '<iframe[^>]*src="\K[^"]+' | head -n 1)
    
    # Nếu không tìm thấy với iframe, thử tìm trong thẻ video
    if [[ -z "$video_url" ]]; then
        video_url=$(echo "$episode_page_content" |
          sed -n '/<div id="video-player".*>/,/<\/div>/p' | # Tìm khối div video player
          grep -oP 'src="\K[^"]+' | head -n 1) # Tìm src bên trong khối đó
    fi


    if [[ -z "$video_url" ]]; then
      echo "Warning: Không tìm thấy URL video cho tập: $episode_title"
      video_url="Không tìm thấy URL"
    fi

    # Xử lý để đảm bảo không có vấn đề với dấu phẩy hoặc dấu nháy kép trong CSV
    escaped_main_title=$(echo "$main_title" | sed 's/"/""/g')
    escaped_episode_title=$(echo "$episode_title" | sed 's/"/""/g')
    escaped_video_url=$(echo "$video_url" | sed 's/"/""/g') # Cũng nên escape URL video cho chắc

    echo "\"$escaped_main_title\",\"$escaped_episode_title\",\"$escaped_video_url\"" >> "$output_file"
    echo "Đã lưu: \"$escaped_episode_title\""
    echo "---"
  done
done < "$url_file"

echo "Xong! Danh sách URL video đã được lưu vào file: $output_file"
