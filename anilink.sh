#!/bin/bash

CSV_FILE="anime.csv"

echo "anime_title,episode_title,episode_url,iframe_src" > "$CSV_FILE"
echo "✅ Đã tạo file '$CSV_FILE' và sẵn sàng ghi dữ liệu."
echo "---"


if [ ! -f "data.txt" ]; then
    echo "❌ Lỗi: Không tìm thấy file 'data.txt'. Hãy tạo file này và thêm link vào nhé."
    exit 1
fi


while IFS= read -r main_url || [[ -n "$main_url" ]]; do

    if [ -z "$main_url" ]; then
        continue
    fi

    echo "⚙️ Đang xử lý trang chính: $main_url"
    
    
    main_page_content=$(curl -sL "$main_url")
    if [ $? -ne 0 ]; then
        echo "❌ Lỗi: Không thể tải nội dung từ '$main_url'. Bỏ qua."
        continue
    fi

    
    main_title=$(echo "$main_page_content" | sed -n 's/.*<h1 class="heading_movie">\([^<]*\)<\/h1>.*/\1/p' | head -n 1)
    
    
    sanitized_title=$(echo "$main_title" | sed 's/[[:space:]]*$//' | sed 's/[[:punct:]]//g' | sed 's/ /_/g')

    if [ -z "$sanitized_title" ]; then
        echo "⚠️  Không tìm thấy tiêu đề cho trang '$main_url'. Bỏ qua."
        continue
    fi
    
    echo "✨ Tìm thấy tiêu đề: '$main_title'"
    
    mkdir -p "$sanitized_title"
    echo "$main_page_content" > "$sanitized_title/index.html"
    echo "📁  Đã tạo thư mục và lưu index.html tại: '$sanitized_title'"

    
    episode_block=$(echo "$main_page_content" | sed -n '/<div class="list-item-episode scroll-bar">/,/<\/div>/p')
    
    
    mapfile -t episode_links < <(echo "$episode_block" | grep -oP '<a href="\K[^"]+')
    
    
    mapfile -t episode_names < <(echo "$episode_block" | grep -oP '<span>\K[^<]+')

    num_episodes=${#episode_links[@]}

    if [ "$num_episodes" -eq 0 ]; then
        echo "🤔 Không tìm thấy tập phim nào cho '$main_title'."
        
        echo "\"$main_title\",\"NO_EPISODES_FOUND\",\"\",\"\"" >> "$CSV_FILE"
        echo "---"
        continue
    fi
    
    echo "🔍 Tìm thấy tổng cộng $num_episodes tập phim. Bắt đầu xử lý từng tập..."
    
    for (( i=0; i<num_episodes; i++ )); do
        episode_path="${episode_links[$i]}"
        
    
        if [[ ! "$episode_path" == http* ]]; then
    
            base_url=$(echo "$main_url" | grep -oP '^(https?://[^/]+)')
            episode_url="$base_url$episode_path"
        else
            episode_url="$episode_path"
        fi

    
        file_number=$((num_episodes - i))
        
        episode_title="${episode_names[$i]}"
        
        echo "    ➡️  Đang xử lý '${episode_title}'..."
        
    
        episode_content=$(curl -sL "$episode_url")
        if [ $? -ne 0 ]; then
            echo "    ❌ Lỗi khi tải '${episode_title}'. Bỏ qua."
            continue
        fi

        echo "$episode_content" > "$sanitized_title/$file_number.html"
        
    
        iframe_src=$(echo "$episode_content" | grep -oP '<iframe id="ss_if"[^>]*src="\K[^"]+')

        if [ -z "$iframe_src" ]; then
             echo "    ❓ Không tìm thấy iframe trong tập: $file_number.html"
             iframe_src="NOT_FOUND"
        fi

    
        echo "\"$main_title\",\"$episode_title\",\"$episode_url\",\"$iframe_src\"" >> "$CSV_FILE"

    done

    echo "✅ Hoàn tất xử lý tất cả các tập của '$main_title'."
    echo "---"

done < "data.txt"

echo "🎉 Mọi thứ đã hoàn tất! hãy kiểm tra file '$CSV_FILE' và các thư mục nhé."
