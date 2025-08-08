
#!/bin/bash
# ===========================================
# Random Font + Random Audio (Ubuntu/Lubuntu)
# Tự tải font & audio mới
# ===========================================

set -e

# --- 0. Chuẩn bị thư mục ---
FONT_DIR="/usr/share/fonts/custom"
SOUND_DIR="/usr/share/sounds/custom"
sudo mkdir -p "$FONT_DIR" "$SOUND_DIR"

# --- 1. TẢI FONT MỚI ---
echo "[*] Đang tải thêm font từ Google Fonts..."
TMP_FONT=$(mktemp -d)
wget -qO "$TMP_FONT/fonts.zip" "https://github.com/google/fonts/archive/refs/heads/main.zip"
unzip -q "$TMP_FONT/fonts.zip" -d "$TMP_FONT"
sudo find "$TMP_FONT" -type f \( -name "*.ttf" -o -name "*.otf" \) -exec cp {} "$FONT_DIR" \;
sudo fc-cache -fv
rm -rf "$TMP_FONT"
echo "    → Đã tải và cài thêm font Google Fonts."

# --- 2. TẢI AUDIO MỚI ---
echo "[*] Đang tải bộ âm thanh mới..."
# Ví dụ: lấy từ Mixkit (không bản quyền)
AUDIO_LINKS=(
    "https://assets.mixkit.co/sfx/preview/mixkit-correct-answer-tone-2870.mp3"
    "https://assets.mixkit.co/sfx/preview/mixkit-retro-game-notification-212.mp3"
    "https://assets.mixkit.co/sfx/preview/mixkit-software-interface-back-2575.mp3"
    "https://assets.mixkit.co/sfx/preview/mixkit-positive-interface-beep-221.mp3"
)

for url in "${AUDIO_LINKS[@]}"; do
    FILE="$SOUND_DIR/$(basename "$url" .mp3).ogg"
    wget -qO - "$url" | ffmpeg -y -loglevel quiet -i - -acodec libvorbis "$FILE"
done
echo "    → Đã tải và chuyển đổi audio sang .ogg."

# --- 3. RANDOM FONT ---
echo "[*] Random font..."
FONTS=$(fc-list :family | cut -d: -f1 | sort -u)
RAND_FONT=$(echo "$FONTS" | shuf -n 1)
echo "    → Font được chọn: $RAND_FONT"

# Ubuntu GNOME
if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface font-name "$RAND_FONT 11"
    gsettings set org.gnome.desktop.wm.preferences titlebar-font "$RAND_FONT Bold 11"
fi

# Lubuntu LXQt
if [ -f ~/.config/lxqt/session.conf ]; then
    sed -i "s/^font=.*/font=$RAND_FONT,11/" ~/.config/lxqt/session.conf
fi

# --- 4. RANDOM AUDIO ---
echo "[*] Random audio..."
SOUND_FILE=$(find "$SOUND_DIR" -type f -name "*.ogg" | shuf -n 1)
if [ -n "$SOUND_FILE" ]; then
    echo "    → Audio được chọn: $SOUND_FILE"
    sudo cp "$SOUND_FILE" "$SOUND_DIR/login.ogg"

    # GNOME
    if command -v gsettings >/dev/null; then
        gsettings set org.gnome.desktop.sound event-sounds true
        gsettings set org.gnome.desktop.sound theme-name "custom"
    fi
else
    echo "    ⚠ Không tìm thấy audio!"
fi

echo "[✔] Hoàn tất! Font & audio mới đã được tải và random."




