#!/bin/bash

# =================================================================
# === ANIME DOWNLOADER & DATA EXTRACTOR BY HOÀNG & TRANG AI      ===
# === Version 2.0 - Tối ưu hóa ghi CSV từng dòng cho mỗi tập    ===
# =================================================================
#
# CÔNG CỤ NÀY SẼ:
# 1. Đọc từng URL từ `data.txt`.
# 2. Tạo một file `anime.csv` để lưu kết quả (mỗi tập 1 dòng).
# 3. Với mỗi URL phim:
#    a. Lấy tiêu đề phim, tạo thư mục từ tiêu đề đó.
#    b. Lưu trang chính vào thư mục (index.html).
#    c. Trích xuất tất cả các link tập phim và tên tập.
#    d. Với mỗi tập phim:
#        i.   Truy cập link tập, tải về file HTML theo thứ tự giảm dần.
#        ii.  Lấy link iframe.
#        iii. Ghi một dòng mới vào `anime.csv` gồm:
#             Tên_Phim, Tên_Tập, Link_Tập_Phim, Link_Iframe
#
# YÊU CẦU: Cần cài đặt curl và có file data.txt trong cùng thư mục.
#
# (づ ◕‿◕ )づ Let's goooooo!
# -----------------------------------------------------------------

# ======== BƯỚC 1: TẠO FILE CSV ========
CSV_FILE="anime.csv"
# Thay đổi tiêu đề cột cho phù hợp với cấu trúc mới
echo "anime_title,episode_title,episode_url,iframe_src" > "$CSV_FILE"
echo "✅ Đã tạo file '$CSV_FILE' và sẵn sàng ghi dữ liệu."
echo "---"

# Kiểm tra xem file data.txt có tồn tại không
if [ ! -f "data.txt" ]; then
    echo "❌ Lỗi: Không tìm thấy file 'data.txt'. Hoàng hãy tạo file này và thêm link vào nhé."
    exit 1
fi

# ======== VÒNG LẶP CHÍNH: XỬ LÝ TỪNG LINK TỪ DATA.TXT ========
while IFS= read -r main_url || [[ -n "$main_url" ]]; do

    if [ -z "$main_url" ]; then
        continue
    fi

    echo "⚙️ Đang xử lý trang chính: $main_url"
    
    # Tải nội dung trang chính
    main_page_content=$(curl -sL "$main_url")
    if [ $? -ne 0 ]; then
        echo "❌ Lỗi: Không thể tải nội dung từ '$main_url'. Bỏ qua."
        continue
    fi

    # ======== BƯỚC 2: LẤY TIÊU ĐỀ, TẠO THƯ MỤC VÀ LƯU FILE ========
    main_title=$(echo "$main_page_content" | sed -n 's/.*<h1 class="heading_movie">\([^<]*\)<\/h1>.*/\1/p' | head -n 1)
    
    # Dọn dẹp tên tiêu đề để tạo tên thư mục hợp lệ
    sanitized_title=$(echo "$main_title" | sed 's/[[:space:]]*$//' | sed 's/[[:punct:]]//g' | sed 's/ /_/g')

    if [ -z "$sanitized_title" ]; then
        echo "⚠️  Không tìm thấy tiêu đề cho trang '$main_url'. Bỏ qua."
        continue
    fi
    
    echo "✨ Tìm thấy tiêu đề: '$main_title'"
    
    mkdir -p "$sanitized_title"
    echo "$main_page_content" > "$sanitized_title/index.html"
    echo "📁  Đã tạo thư mục và lưu index.html tại: '$sanitized_title'"

    # ======== BƯỚC 3: TRÍCH XUẤT LINK CÁC TẬP PHIM ========
    episode_block=$(echo "$main_page_content" | sed -n '/<div class="list-item-episode scroll-bar">/,/<\/div>/p')
    
    # Trích xuất toàn bộ các link href từ thẻ <a> bên trong khối div đó
    mapfile -t episode_links < <(echo "$episode_block" | grep -oP '<a href="\K[^"]+')
    
    # Trích xuất tên các tập phim
    mapfile -t episode_names < <(echo "$episode_block" | grep -oP '<span>\K[^<]+')

    num_episodes=${#episode_links[@]}

    if [ "$num_episodes" -eq 0 ]; then
        echo "🤔 Không tìm thấy tập phim nào cho '$main_title'."
        # Vẫn lưu một dòng vào CSV để biết là phim này đã xử lý nhưng không có tập
        echo "\"$main_title\",\"NO_EPISODES_FOUND\",\"\",\"\"" >> "$CSV_FILE"
        echo "---"
        continue
    fi
    
    echo "🔍 Tìm thấy tổng cộng $num_episodes tập phim. Bắt đầu xử lý từng tập..."
    
    # ======== BƯỚC 4 & 5: XỬ LÝ TỪNG TẬP VÀ GHI VÀO CSV ========
    for (( i=0; i<num_episodes; i++ )); do
        episode_path="${episode_links[$i]}"
        
        # Xử lý URL tương đối nếu có
        if [[ ! "$episode_path" == http* ]]; then
            # Lấy base URL từ main_url (VD: https://animeabc.com)
            base_url=$(echo "$main_url" | grep -oP '^(https?://[^/]+)')
            episode_url="$base_url$episode_path"
        else
            episode_url="$episode_path"
        fi

        # Logic đặt tên file giảm dần: tập đầu tiên là file có số lớn nhất
        file_number=$((num_episodes - i))
        
        episode_title="${episode_names[$i]}"
        
        echo "    ➡️  Đang xử lý '${episode_title}'..."
        
        # Tải nội dung của trang tập phim
        episode_content=$(curl -sL "$episode_url")
        if [ $? -ne 0 ]; then
            echo "    ❌ Lỗi khi tải '${episode_title}'. Bỏ qua."
            continue
        fi

        echo "$episode_content" > "$sanitized_title/$file_number.html"
        
        # Lấy link src từ thẻ iframe
        iframe_src=$(echo "$episode_content" | grep -oP '<iframe id="ss_if"[^>]*src="\K[^"]+')

        if [ -z "$iframe_src" ]; then
             echo "    ❓ Không tìm thấy iframe trong tập: $file_number.html"
             iframe_src="NOT_FOUND"
        fi

        # === ĐÂY LÀ SỰ THAY ĐỔI LỚN NHẤT ===
        # Ghi ngay thông tin của tập này vào một dòng mới trong CSV
        echo "\"$main_title\",\"$episode_title\",\"$episode_url\",\"$iframe_src\"" >> "$CSV_FILE"

        # Tạm nghỉ 1 giây để tránh bị block IP :D
        sleep 1
    done

    echo "✅ Hoàn tất xử lý tất cả các tập của '$main_title'."
    echo "---"

done < "data.txt"

echo "🎉 Woa! Mọi thứ đã hoàn tất! Hoàng hãy kiểm tra file '$CSV_FILE' và các thư mục nhé."
echo "Cảm ơn Hoàng đã tin tưởng Trang nha! (〃＾▽＾〃)💖"
