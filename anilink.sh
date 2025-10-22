#!/bin/bash

# --- CONFIGURATION ---
CSV_FILE="anime.csv"
DATA_SOURCE="data.txt"

# --- INITIALIZATION ---
# Kiểm tra nếu file CSV chưa tồn tại thì tạo mới và thêm header
if [ ! -f "$CSV_FILE" ]; then
    echo "anime_title,episode_title,episode_url,iframe_src" > "$CSV_FILE"
    echo "✅ Đã tạo file '$CSV_FILE' và sẵn sàng ghi dữ liệu."
fi
echo "---"

# Kiểm tra sự tồn tại của file data.txt
if [ ! -f "$DATA_SOURCE" ]; then
    echo "❌ Lỗi: Không tìm thấy file '$DATA_SOURCE'. Hãy tạo file này và thêm link vào nhé."
    exit 1
fi

# --- MAIN PROCESSING LOOP ---
# Vòng lặp sẽ tiếp tục chạy miễn là file data.txt còn nội dung (chưa bị trống)
while [ -s "$DATA_SOURCE" ]; do
    
    # Đọc DÒNG ĐẦU TIÊN của file data.txt vào biến main_url
    main_url=$(head -n 1 "$DATA_SOURCE")

    # Bỏ qua nếu dòng rỗng (trường hợp file có dòng trống cuối)
    if [ -z "$main_url" ]; then
        # Xóa dòng trống này và tiếp tục vòng lặp
        sed -i '1d' "$DATA_SOURCE" 
        continue
    fi

    echo "⚙️ Đang xử lý trang chính: $main_url"
    
    # Tải nội dung trang chính
    main_page_content=$(curl -sL "$main_url")
    if [ $? -ne 0 ]; then
        echo "❌ Lỗi: Không thể tải nội dung từ '$main_url'. Bỏ qua."
        # Xóa dòng này đi để không xử lý lại trong lần chạy sau
        sed -i '1d' "$DATA_SOURCE"
        continue
    fi
    
    # Trích xuất tiêu đề chính
    main_title=$(echo "$main_page_content" | sed -n 's/.*<h1 class="heading_movie">\([^<]*\)<\/h1>.*/\1/p' | head -n 1)
    
    # Làm sạch tiêu đề để tạo tên thư mục hợp lệ
    sanitized_title=$(echo "$main_title" | sed 's/[[:space:]]*$//' | sed 's/[[:punct:]]//g' | sed 's/ /_/g')

    if [ -z "$sanitized_title" ]; then
        echo "⚠️  Không tìm thấy tiêu đề cho trang '$main_url'. Bỏ qua."
        sed -i '1d' "$DATA_SOURCE"
        continue
    fi
    
    echo "✨ Tìm thấy tiêu đề: '$main_title'"
    
    # Tạo thư mục và lưu index.html
    mkdir -p "$sanitized_title"
    echo "$main_page_content" > "$sanitized_title/index.html"
    echo "📁  Đã tạo thư mục và lưu index.html tại: '$sanitized_title'"

    # Trích xuất khối chứa danh sách các tập
    episode_block=$(echo "$main_page_content" | sed -n '/<div class="list-item-episode scroll-bar">/,/<\/div>/p')
    
    # Lấy link và tên của từng tập
    mapfile -t episode_links < <(echo "$episode_block" | grep -oP '<a href="\K[^"]+')
    mapfile -t episode_names < <(echo "$episode_block" | grep -oP '<span>\K[^<]+')

    num_episodes=${#episode_links[@]}

    if [ "$num_episodes" -eq 0 ]; then
        echo "🤔 Không tìm thấy tập phim nào cho '$main_title'."
        echo "\"$main_title\",\"NO_EPISODES_FOUND\",\"\",\"\"" >> "$CSV_FILE"
        echo "---"
        # XỬ LÝ XONG URL NÀY, TIẾN HÀNH XÓA DÒNG ĐẦU TIÊN CỦA data.txt
        sed -i '1d' "$DATA_SOURCE"
        continue
    fi
    
    echo "🔍 Tìm thấy tổng cộng $num_episodes tập phim. Bắt đầu xử lý từng tập..."
    
    for (( i=0; i<num_episodes; i++ )); do
        episode_path="${episode_links[$i]}"
        
        # Xây dựng URL đầy đủ cho tập phim
        if [[ ! "$episode_path" == http* ]]; then
            base_url=$(echo "$main_url" | grep -oP '^(https?://[^/]+)')
            episode_url="$base_url$episode_path"
        else
            episode_url="$episode_path"
        fi

        # Tính toán số thứ tự file (để lưu file theo thứ tự ngược)
        file_number=$((num_episodes - i))
        episode_title="${episode_names[$i]}"
        
        echo "    ➡️  Đang xử lý '${episode_title}'..."
        
        # Tải nội dung của trang tập phim
        episode_content=$(curl -sL "$episode_url")
        if [ $? -ne 0 ]; then
            echo "    ❌ Lỗi khi tải '${episode_title}'. Bỏ qua."
            # Ghi nhận lỗi nhưng vẫn tiếp tục với các tập khác
            echo "\"$main_title\",\"$episode_title\",\"$episode_url\",\"CURL_ERROR\"" >> "$CSV_FILE"
            continue
        fi
        
        # Lưu nội dung tập phim vào file
        echo "$episode_content" > "$sanitized_title/$file_number.html"
        
        # Trích xuất src từ thẻ iframe
        iframe_src=$(echo "$episode_content" | grep -oP '<iframe id="ss_if"[^>]*src="\K[^"]+')

        if [ -z "$iframe_src" ]; then
             echo "    ❓ Không tìm thấy iframe trong tập: $file_number.html"
             iframe_src="NOT_FOUND"
        fi

        # Ghi thông tin vào file CSV
        echo "\"$main_title\",\"$episode_title\",\"$episode_url\",\"$iframe_src\"" >> "$CSV_FILE"

    done

    echo "✅ Hoàn tất xử lý tất cả các tập của '$main_title'."
    
    sed -i '1d' "$DATA_SOURCE"
    echo "🗑️  Đã xử lý và xóa URL '$main_url' khỏi file '$DATA_SOURCE'."
    
    echo "---"

done

echo "🎉 Mọi thứ đã hoàn tất! File '$DATA_SOURCE' giờ đã trống."
echo "   Hãy kiểm tra file '$CSV_FILE' và các thư mục nhé, Big Boss Dữ Liệu! (ง •̀_•́)ง"
