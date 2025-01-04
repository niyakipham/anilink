#!/bin/bash

# URL gốc của trang web
base_url="https://animehay.name/the-loai/anime-1/trang-"
output_file="anime_links.txt"

# Hàm để lấy các liên kết từ một trang cụ thể
get_links_from_page() {
  page_number="$1"
  url="${base_url}${page_number}.html"

  echo "Đang xử lý trang: $url"

  curl -s "$url" |
    grep '<div class="movies-list">' -A 500 |
    grep '<a href="' |
    sed 's/.*href="\([^"]*\)".*/\1/g' >> "$output_file"
}

# Lấy số trang cuối từ thuộc tính javascript:goPage()
total_pages=$(curl -s "$base_url"1.html |
              grep 'form action="javascript:goPage(' |
              sed 's/.*javascript:goPage(\([0-9]*\)).*/\1/')

if [[ -z "$total_pages" ]]; then
  echo "Không tìm thấy thông tin số trang. Kiểm tra lại trang web."
  exit 1
fi

echo "Tổng số trang cần quét: $total_pages"

# Lặp qua các trang và lấy liên kết
for ((i=1; i<=$total_pages; i++)); do
  get_links_from_page "$i"
done

echo "Đã lưu tất cả các liên kết vào file: $output_file"
