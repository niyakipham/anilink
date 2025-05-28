#!/binbash

# ====[ 💡 THIẾT LẬP BIẾN "VŨ TRỤ" ]====
# File chứa danh sách URL chính của các bộ phim
url_file="data.txt"
# Tên file CSV đầu ra do người dùng nhập
output_file=""
# Tên file log - "Nhật ký hành trình"
log_file="thu_hoach_video_$(date +'%Y%m%d_%H%M%S').log"
# Số lần thử lại tối đa cho mỗi yêu cầu curl
max_retries=3
# Thời gian chờ giữa các lần thử lại (giây)
retry_delay=5
# User-Agent "giả danh" trình duyệt xịn
user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
# Số lượng tác vụ song song tối đa cho xargs khi xử lý link tập
max_parallel_episodes=4 # Hoàng có thể điều chỉnh con số này nhé!

# ====[  फंक्शन - CHỨC NĂNG "NHỎ NHƯNG CÓ VÕ" ]====

# Chức năng ghi log - đẹp và rõ ràng
log_message() {
  local type="$1"
  local message="$2"
  echo "$(date +'%Y-%m-%d %H:%M:%S') | ${type} | ${message}" | tee -a "$log_file"
}

# Chức năng "Curl Thần Sầu" với retry logic và User-Agent
curl_with_retry() {
  local url_to_fetch="$1"
  local attempt_num=1
  while [[ $attempt_num -le $max_retries ]]; do
    response=$(curl -A "$user_agent" --silent --location --connect-timeout 10 --max-time 30 "$url_to_fetch")
    if [[ $? -eq 0 && -n "$response" ]]; then
      echo "$response"
      return 0
    fi
    log_message "WARNING" "Curl thất bại cho ${url_to_fetch} (Lần thử: ${attempt_num}/${max_retries}). Đang thử lại sau ${retry_delay} giây..."
    sleep "$retry_delay"
    ((attempt_num++))
  done
  log_message "ERROR" "Curl thất bại hoàn toàn cho ${url_to_fetch} sau ${max_retries} lần thử."
  return 1
}

# Hàm xử lý một link tập phim duy nhất (sẽ được gọi bởi xargs)
process_single_episode_link() {
  local episode_link_input="$1" # Input format: "MainTitle\tEpisodeTitle\tEpisodeLink"
  local current_output_file="$2"

  # Tách thông tin từ input
  # Cẩn thận với IFS và dấu tab nếu tên có ký tự đặc biệt (đã xử lý bằng trích dẫn kép sau này)
  IFS=$'\t' read -r main_title_ep episode_title_ep episode_original_link <<< "$episode_link_input"

  log_message "INFO" "  Đang xử lý link tập: ${episode_title_ep} - ${episode_original_link}"
  episode_page_content=$(curl_with_retry "$episode_original_link")

  if [[ -n "$episode_page_content" ]]; then
    video_final_url=$(echo "$episode_page_content" |
      # Trích URL từ <div id="video-player">... src="..." ...</div>
      # Biểu thức chính quy được tinh chỉnh để chính xác hơn và linh hoạt hơn
      # grep -oP '<\s*div[^>]*id\s*=\s*["'"'"']video-player["'"'"'][^>]*>.*?<\s*iframe[^>]*src\s*=\s*["'"'"']([^"'"'"']+)["'"'"']' | sed -E 's/.*src=['"'"'"]([^'"'"'"]*)['"'"'"].*/\1/' || # Dòng này nếu dùng iframe
      # Giả sử src nằm ngay trong div player hoặc trong source/video tag
      grep -oP 'id\s*=\s*["'"'"']video-player["'"'"'][^>]*src\s*=\s*["'"'"']\K[^"'"'"']+' || \
      grep -oP 'id\s*=\s*["'"'"']video-player["'"'"'][^>]*<source[^>]*src\s*=\s*["'"'"']\K[^"'"'"']+' || \
      grep -oP 'id\s*=\s*["'"'"']video-player["'"'"'][^>]*<video[^>]*src\s*=\s*["'"'"']\K[^"'"'"']+' )


    if [[ -z "$video_final_url" ]]; then
      log_message "WARNING" "  ⚠️ Không tìm thấy URL video cho tập: ${episode_title_ep}"
      video_final_url="Không tìm thấy URL"
    else
       # Check if the extracted URL is relative, and if so, prepend the main domain
        if [[ "$video_final_url" =~ ^/ ]]; then # Bắt đầu bằng / (vd: /video.mp4)
            # Cần base URL, ví dụ từ episode_original_link
            base_url_for_video=$(echo "$episode_original_link" | sed -E 's|^(https?://[^/]+).*|\1|')
            video_final_url="${base_url_for_video}${video_final_url}"
            log_message "INFO" "  Phát hiện URL tương đối, đã chuyển đổi: ${video_final_url}"
        elif [[ ! "$video_final_url" =~ ^https?:// ]]; then # Không bắt đầu bằng http/https và không phải / (vd: video.mp4)
            base_path_for_video=$(dirname "$episode_original_link")
            # Handle potential .. in relative paths, although this is less common for video src
            # This is a simple prepend, more robust path joining might be needed if complex relative paths occur
            video_final_url="${base_path_for_video}/${video_final_url}"
            # Normalize paths like a/b/../c to a/c. `realpath` is good but might not always be available or desired for URLs.
            # For URLs, usually better to get them directly as absolute. This part might be overkill or not robust enough
            # depending on how sites structure their relative video URLs.
            log_message "INFO" "  Phát hiện URL tương đối dạng khác, đã chuyển đổi: ${video_final_url}"
        fi
    fi
  else
    log_message "ERROR" "  Không thể tải nội dung trang tập: ${episode_original_link}"
    video_final_url="Lỗi tải trang tập"
  fi

  # Xử lý ký tự đặc biệt trong title để chuẩn CSV hơn
  escaped_main_title_ep=$(echo "$main_title_ep" | sed 's/"/""/g')
  escaped_episode_title_ep=$(echo "$episode_title_ep" | sed 's/"/""/g')

  # Ghi vào file CSV (xargs cần đường dẫn tuyệt đối hoặc xử lý trong cùng thư mục)
  # Sử dụng `flock` để đảm bảo ghi file an toàn khi xử lý song song
  (
    flock -x 200 || exit 1
    echo "\"$escaped_main_title_ep\",\"$escaped_episode_title_ep\",\"$video_final_url\"" >> "$current_output_file"
  ) 200>"${current_output_file}.lock"


  log_message "INFO" "    🎞️ Title: ${main_title_ep} | Tập: ${episode_title_ep} | URL Video: ${video_final_url}"
  # Tạo một dòng ----- ngẫu nhiên chiều dài và ký tự
  # printf '%*s\n' $(( RANDOM % 30 + 20 )) '' | tr ' ' '-' >> "$log_file" # Kiểu Hoàng cũ
  log_message "SEPARATOR" "────────────────────────────────────────────" # Kiểu mới "chất lừ" của Trang
}

# Export hàm để xargs có thể "nhìn thấy"
export -f log_message
export -f curl_with_retry
export -f process_single_episode_link

# ====[ 🎬 BẮT ĐẦU "CUỘC ĐUA" ]====
log_message "INFO" "====== KHỞI ĐỘNG SCRIPT THU HOẠCH VIDEO URL ======"
log_message "INFO" "User Agent được sử dụng: $user_agent"

# --- Yêu cầu nhập tên file và kiểm tra ---
# (Giữ nguyên logic của Hoàng vì nó rất ổn!)
read -r -p "✨ Hoàng ơi, nhập tên file đầu ra (VD: ket_qua.csv): " output_file
while [[ ! "$output_file" =~ \.csv$ ]]; do
  log_message "ERROR" "Tên file '$output_file' không hợp lệ."
  read -r -p "🥺 Lỗi rồi Hoàng ơi! Tên file phải có đuôi .csv nha (VD: my_anime_list.csv): " output_file
done
log_message "INFO" "File đầu ra sẽ là: $output_file"

# --- Kiểm tra file URL ---
if [[ ! -f "$url_file" ]]; then
  log_message "CRITICAL" "🛑 Lỗi nghiêm trọng: File URL '$url_file' không tồn tại. Script sẽ dừng lại."
  exit 1
fi
log_message "INFO" "Đang sử dụng file danh sách URL: $url_file"

# --- Chuẩn bị file CSV đầu ra ---
if [[ ! -s "$output_file" ]]; then
    log_message "INFO" "Tạo file CSV mới và thêm dòng tiêu đề."
    echo "Title,Episode,URL" > "$output_file"
else
    log_message "WARNING" "File CSV '$output_file' đã tồn tại và có nội dung. Dữ liệu mới sẽ được ghi tiếp vào cuối file."
fi

# ====[ 🗺️ "KHÁM PHÁ" TỪNG BỘ PHIM (URL CHÍNH) ]====
while IFS= read -r main_url; do
  main_url_trimmed=$(echo "$main_url" | xargs) # Loại bỏ khoảng trắng thừa
  if [[ -z "$main_url_trimmed" ]]; then
      log_message "WARNING" "Phát hiện dòng trống trong $url_file, bỏ qua."
      continue
  fi
  log_message "INFO" "--- Bắt đầu xử lý URL chính: ${main_url_trimmed} ---"

  main_page_content=$(curl_with_retry "$main_url_trimmed")

  if [[ -z "$main_page_content" ]]; then
    log_message "ERROR" "Không thể tải nội dung cho URL chính: $main_url_trimmed. Bỏ qua URL này."
    continue
  fi

  # --- Lấy Tiêu đề chính của Bộ phim ---
  # Regex đã được Hoàng trau chuốt, Trang giữ nguyên tinh thần!
  current_main_title=$(echo "$main_page_content" | sed -n 's/.*<h1 class="heading_movie">\([^<]*\)<\/h1>.*/\1/p' | xargs) # Thêm xargs để trim

  if [[ -z "$current_main_title" ]]; then
    log_message "WARNING" "Không tìm thấy tiêu đề chính trên trang: $main_url_trimmed"
    current_main_title="Không tìm thấy tiêu đề phim"
  else
    log_message "INFO" "Tiêu đề phim: \"${current_main_title}\""
  fi

  # --- Lấy Link và Tiêu đề các tập ---
  # Trang giữ nguyên regex của Hoàng, nhưng đảm bảo an toàn hơn với tên
  # Regex gốc của Hoàng
  #   episode_links=$(echo "$main_page" |
  #   sed -n '/<div class="list-item-episode scroll-bar">/,/<\/div>/p' |
  #   grep -o '<a[^>]*href=['"'"'"][^'"'"'"]*['"'"'"][^>]*>' |
  #   sed -E 's/.*href=['"'"'"]([^'"'"'"]*)['"'"'"].*/\1/')

  # Regex được cải tiến để tương thích với grep -P (PCRE) cho trích xuất an toàn hơn
  # và trích thẳng phần URL, tránh lỗi với sed
  episode_data_block=$(echo "$main_page_content" | sed -n '/<div class="list-item-episode scroll-bar">/,/<\/div>/p')

  # Tạo một list các cặp "Episode Title\tEpisode Link"
  # IFS trick này để đọc các dòng một cách an toàn, tránh word splitting không mong muốn.
  # Awk sẽ xử lý html tốt hơn sed trong trường hợp phức tạp này.
  mapfile -t episode_title_link_pairs < <(echo "$episode_data_block" | awk -v main_t_esc="$(echo "$current_main_title" | sed 's/\t/ /g')" '
  BEGIN { RS="<a"; FS="href=['\"]"; OFS="\t" }
  /class="episode-item"/ {
    if (split($2, parts, /["']/) > 0) {
        link = parts[1];
        if (getline tmp_title < "/dev/stdin") { # Cần khéo léo đọc tiếp nội dung thẻ a để lấy title
             # Đơn giản hóa: lấy text giữa thẻ <span> gần nhất trong <a>, sẽ có thể cần cải thiện
            if (match(tmp_title, /<span>([^<]+)<\/span>/, arr_title)) {
                episode_title = arr_title[1];
            } else if (match(tmp_title, />([^<]+)<\/a>/, arr_title_fallback)) {
                 episode_title = arr_title_fallback[1]; # Lấy text bất kỳ ngay trước </a> nếu không có span
            } else {
                 episode_title = "Tập không rõ tên";
            }

            # Làm sạch title
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", episode_title);
            gsub(/\t/, " ", episode_title); # Thay tab trong title để không phá hỏng định dạng TSV
            print main_t_esc, episode_title, link;
        }
      }
  }
  ' RS='<a ') # Khôi phục RS default cho lệnh echo ngoài
  # Điều chỉnh AWK và mapfile để chuẩn bị cho xargs
  # Đầu vào cho xargs cần mỗi dòng là một item xử lý. Ở đây, mỗi dòng sẽ là: MainTitle<TAB>EpisodeTitle<TAB>EpisodeLink

  if [ ${#episode_title_link_pairs[@]} -eq 0 ]; then
      log_message "WARNING" "Không tìm thấy link tập nào cho: ${current_main_title}"
      continue
  fi

  log_message "INFO" "Tìm thấy ${#episode_title_link_pairs[@]} tập. Bắt đầu xử lý song song..."

  # Sử dụng xargs để xử lý song song
  # Input cho xargs là các dòng "MainTitle<TAB>EpisodeTitle<TAB>EpisodeLink"
  printf "%s\n" "${episode_title_link_pairs[@]}" | xargs -P "$max_parallel_episodes" -I {} bash -c "process_single_episode_link '{}' '$output_file'"
  # {} là placeholder cho mỗi dòng từ input
  # '$output_file' là truyền biến output_file vào hàm process_single_episode_link


  log_message "INFO" "--- Hoàn thành xử lý các tập cho: ${current_main_title} ---"

done < "$url_file"

# Dọn dẹp file lock
if [ -f "${output_file}.lock" ]; then
    rm -f "${output_file}.lock"
fi

log_message "INFO" "✨👑 Xong! Hoàng thượng ơi, danh sách URL video đã được 'dâng lên' vào file: $output_file"
log_message "INFO" "====== KẾT THÚC SCRIPT ======"
echo "Xong! Danh sách URL video đã được lưu vào file: $output_file"
echo "Nhật ký chi tiết đã được ghi tại: $log_file"
