#!/bin/bash

# Script tự động thay đổi WebGL, Canvas, Audio và Client Rects trên Ubuntu/Lubuntu trong VMware

# Kiểm tra hệ điều hành (Ubuntu hoặc Lubuntu)
if [ -x "$(command -v lxqt-config)" ]; then
    GUI_ENV="Lubuntu"
else
    GUI_ENV="Ubuntu"
fi

echo "Đang chạy trên $GUI_ENV."

# -------------------------------------
# Bước 1: Thay đổi WebGL (GPU)
# -------------------------------------

# Đường dẫn file cấu hình của VMware
VMX_FILE="$HOME/.vmware/your_vm.vmx"

# Xóa file cấu hình cũ
if [ -f "$VMX_FILE" ]; then
    echo "Đang xóa file cấu hình cũ..."
    rm -f "$VMX_FILE"
fi

# Random cấu hình GPU
GPU_VENDOR=("0x10de" "0x8086" "0x1002" "0x1414" "0x1043")
GPU_DEVICE=("0x1eb8" "0x1d01" "0x6810" "0x0000" "0x6780")
GPU_VRAM=("134217728" "67108864" "268435456" "536870912")

# Lựa chọn ngẫu nhiên các giá trị
RANDOM_VENDOR=${GPU_VENDOR[$RANDOM % ${#GPU_VENDOR[@]}]}
RANDOM_DEVICE=${GPU_DEVICE[$RANDOM % ${#GPU_DEVICE[@]}]}
RANDOM_VRAM=${GPU_VRAM[$RANDOM % ${#GPU_VRAM[@]}]}

# Tạo file cấu hình VMware mới với các giá trị ngẫu nhiên
echo "Đang tạo cấu hình GPU ngẫu nhiên..."
echo 'svga.present = "TRUE"' > "$VMX_FILE"
echo "svga.vramSize = \"$RANDOM_VRAM\"" >> "$VMX_FILE"
echo "svga.vendorID = \"$RANDOM_VENDOR\"" >> "$VMX_FILE"
echo "svga.deviceID = \"$RANDOM_DEVICE\"" >> "$VMX_FILE"

# Cài đặt OpenGL/Mesa
echo "Đang cài đặt OpenGL/Mesa..."
sudo apt update
sudo apt install -y mesa-utils

# Kiểm tra OpenGL
echo "Kiểm tra OpenGL..."
glxinfo | grep "OpenGL"

# -------------------------------------
# Bước 2: Thay đổi Canvas (Font & DPI)
# -------------------------------------

# Random DPI và text scaling factor
DPI_SCALE=("1.0" "1.2" "1.5" "1.8" "2.0" "1.3" "1.6" "1.4" "1.7")
RANDOM_DPI=${DPI_SCALE[$RANDOM % ${#DPI_SCALE[@]}]}

echo "Thay đổi DPI của màn hình với scaling factor $RANDOM_DPI..."
gsettings set org.gnome.desktop.interface text-scaling-factor "$RANDOM_DPI"

# -------------------------------------

# -------------------------------------
# Bước 3: Random hóa Font chữ (APT + Google Fonts GitHub)
# -------------------------------------
#!/bin/bash

# Check nếu chạy với sudo
if [ "$EUID" -ne 0 ]; then
    echo "[Error] Vui lòng chạy script với sudo: sudo ./$0"
    exit 1
fi

# Set GUI_ENV nếu chưa có (mặc định Ubuntu nếu không set)
if [ -z "$GUI_ENV" ]; then
    GUI_ENV="Ubuntu"
    echo "[Warn] GUI_ENV chưa set, mặc định dùng $GUI_ENV."
fi

# 0) Cài jq nếu chưa có
if ! command -v jq >/dev/null; then
    echo "[Font] Đang cài jq..."
    apt update
    apt install -y jq
fi

# 1) Xóa font cũ (thêm timeout confirm để tránh treo khi paste)
echo "[Font] Đang xóa font cũ từ /usr/local/share/fonts/custom... (Y/n, tự Y sau 5s)"
read -t 5 -p "" confirm
if [ -z "$confirm" ] || [ "$confirm" != "n" ]; then
    rm -rf /usr/local/share/fonts/custom
    fc-cache -f
else
    echo "[Font] Bỏ qua xóa font cũ."
fi

# 2) Lấy danh sách font từ hệ thống
SYS_FONTS=($(fc-list : family | sort -u | tr -d ',' | tr ' ' '_'))

# 3) Lấy danh sách font từ Google Fonts API
echo "[Font] Đang tải danh sách font từ Google Fonts API..."
FONTLIB_JSON=$(curl -s "https://www.googleapis.com/webfonts/v1/webfonts?sort=popularity")
if [ -z "$FONTLIB_JSON" ] || ! echo "$FONTLIB_JSON" | jq . >/dev/null 2>&1; then
    echo "[Error] Không tải được JSON. Kiểm tra internet hoặc proxy. Exit."
    exit 1
fi
LIB_FONTS=($(echo "$FONTLIB_JSON" | jq -r '.items[:50] | .[].family' | tr ' ' '_'))  # Top 50 cho nhanh

# 4) Quyết định nguồn (70% GoogleFonts, 30% System)
if (( RANDOM % 100 < 70 )); then
    SOURCE="GoogleFonts"
    FONT_LIST=("${LIB_FONTS[@]}")
else
    SOURCE="System"
    FONT_LIST=("${SYS_FONTS[@]}")
fi

# 5) Chọn font ngẫu nhiên
if [ ${#FONT_LIST[@]} -eq 0 ]; then
    echo "[Error] Không có font nào. Exit."
    exit 1
fi
RANDOM_FONT=${FONT_LIST[$RANDOM % ${#FONT_LIST[@]}]}
RANDOM_FONT_NAME=$(echo "$RANDOM_FONT" | tr '_' ' ')
echo "[Font] Nguồn: $SOURCE | Font: $RANDOM_FONT_NAME"

# 6) Nếu từ GoogleFonts → tải & cài
if [ "$SOURCE" = "GoogleFonts" ]; then
    FONT_INFO=$(echo "$FONTLIB_JSON" | jq --arg family "$RANDOM_FONT_NAME" '.items[] | select(.family==$family)')
    FONT_URL=$(echo "$FONT_INFO" | jq -r '.files.regular // .files["400"] // null')
    if [ -n "$FONT_URL" ] && [ "$FONT_URL" != "null" ]; then
        TMP_DIR=$(mktemp -d)
        if wget -q -O "$TMP_DIR/font.ttf" "$FONT_URL"; then
            mkdir -p /usr/local/share/fonts/custom
            cp "$TMP_DIR/font.ttf" /usr/local/share/fonts/custom/
            fc-cache -f
            echo "[Font] Đã cài font từ Google Fonts."
        else
            echo "[Error] Tải font thất bại. Kiểm tra URL: $FONT_URL"
        fi
        rm -rf "$TMP_DIR"
    else
        echo "[Error] Không tìm thấy URL font. Bỏ qua."
    fi
fi

# 7) Set font hệ thống
if [ "$GUI_ENV" = "Ubuntu" ]; then
    gsettings set org.gnome.desktop.interface font-name "$RANDOM_FONT_NAME 11"
    echo "[Font] Đã set cho Ubuntu. Logout để apply."
elif [ "$GUI_ENV" = "Lubuntu" ]; then
    if command -v lxqt-config-appearance >/dev/null; then
        lxqt-config-appearance --font "$RANDOM_FONT_NAME,11"
        echo "[Font] Đã set cho Lubuntu. Restart session để apply."
    else
        echo "[Error] lxqt-config-appearance không tồn tại. Cài gói lxqt-config hoặc edit thủ công ~/.config/lxqt/session.conf"
    fi
else
    echo "[Error] GUI_ENV không hỗ trợ: $GUI_ENV"
fi


# -------------------------------------
# Bước 4: Audio (XÓA CŨ HẲN + TẠO MỚI)
# -------------------------------------
set -e

echo "[Audio] Dọn dẹp cấu hình cũ…"

# 0) Kill/restart user audio stack để giải phóng file/thiết bị
if systemctl --user status pipewire-pulse >/dev/null 2>&1; then
  systemctl --user stop pipewire-pulse pipewire wireplumber || true
elif command -v pulseaudio >/dev/null 2>&1; then
  pulseaudio -k || true
fi

# 1) Unload các null-sink đã load (runtime, nếu có)
if command -v pactl >/dev/null 2>&1; then
  for mid in $(pactl list short modules 2>/dev/null | awk '/module-null-sink/ {print $1}'); do
    pactl unload-module "$mid" || true
  done
fi

# 2) XÓA các file cấu hình audio do script cũ có thể đã tạo
sudo rm -f \
  /etc/modules-load.d/10-audio.conf \
  /etc/modprobe.d/10-alsa-index.conf \
  /etc/modprobe.d/15-audio-blacklist.conf \
  /etc/modprobe.d/20-snd_*.conf \
  /etc/alsa/conf.d/99-default.conf

# 3) Làm sạch /etc/pulse/*
#    - gỡ các dòng đã từng thêm: module-null-sink, set-default-sink, sample/fragment
if [ -f /etc/pulse/default.pa ]; then
  sudo sed -i '/module-null-sink/d;/set-default-sink/d' /etc/pulse/default.pa || true
fi
if [ -f /etc/pulse/daemon.conf ]; then
  sudo sed -i '/^default-sample-rate/d;/^alternate-sample-rate/d;/^default-fragments/d;/^default-fragment-size-msec/d' /etc/pulse/daemon.conf || true
fi

# 4) PipeWire: xóa client.conf tùy biến ở user (nếu có)
rm -f ~/.config/pipewire/client.conf 2>/dev/null || true

# 5) Xóa trạng thái ALSA (tùy chọn), để kernel tái khởi tạo gọn gàng
sudo rm -f /var/lib/alsa/asound.state 2>/dev/null || true

# 6) Unload các module ứng viên (nếu đang nạp)
sudo modprobe -r snd_usb_audio snd_ens1371 snd_intel8x0 snd_via82xx snd_hda_intel 2>/dev/null || true

echo "[Audio] Dọn xong. Bắt đầu tạo cấu hình MỚI (random + persist)…"

# ====== TẠO MỚI (random + persist) ======

# Phát hiện phần cứng có sẵn
HAS_ENS1371=$(lspci -nn | grep -qi 'Ensoniq AudioPCI'; echo $?)
HAS_USB_AUDIO=$(lsusb 2>/dev/null | grep -qi 'Audio'; echo $?)

CANDS=()
[ "$HAS_ENS1371" -eq 0 ] && CANDS+=("snd_ens1371")
[ "$HAS_USB_AUDIO" -eq 0 ] && CANDS+=("snd_usb_audio")
[ ${#CANDS[@]} -eq 0 ] && CANDS=("snd_ens1371") # fallback VMware

TARGET=${CANDS[$RANDOM % ${#CANDS[@]}]}
ALSA_ID="AUD$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)"

# sample-rate/fragment ngẫu nhiên (hợp lệ)
RATES=(44100 48000 96000); FRAGS=(2 3 4); FSIZES=(1024 2048 4096)
RATE=${RATES[$RANDOM % ${#RATES[@]}]}
FR=${FRAGS[$RANDOM % ${#FRAGS[@]}]}
FS=${FSIZES[$RANDOM % ${#FSIZES[@]}]}

echo "[Audio] Module: $TARGET | ALSA ID: $ALSA_ID | rate=$RATE frags=$FR fragsize=$FS"

# Nạp module mục tiêu khi boot
echo "$TARGET" | sudo tee /etc/modules-load.d/10-audio.conf >/dev/null

# Đặt card thứ tự: module mục tiêu là card 0
echo "options snd slots=$TARGET" | sudo tee /etc/modprobe.d/10-alsa-index.conf >/dev/null

# Đặt ID hiển thị cho card (persist)
sudo bash -c "cat >/etc/modprobe.d/20-${TARGET}.conf" <<EOF
options ${TARGET} index=0 id=${ALSA_ID}
EOF

# Blacklist các ứng viên còn lại (để không tranh card 0)
sudo bash -c 'cat >/etc/modprobe.d/15-audio-blacklist.conf' <<'EOF'
# sẽ được bổ sung ngay dưới
EOF
for m in "${CANDS[@]}"; do
  [ "$m" != "$TARGET" ] && echo "blacklist $m" | sudo tee -a /etc/modprobe.d/15-audio-blacklist.conf >/dev/null
done

# ALSA default -> card 0
sudo mkdir -p /etc/alsa/conf.d
sudo bash -c 'cat >/etc/alsa/conf.d/99-default.conf' <<'EOF'
defaults.pcm.card 0
defaults.ctl.card 0
EOF

# PulseAudio: set tham số random (nếu dùng)
if command -v pulseaudio >/dev/null 2>&1; then
  sudo sed -i '/^default-sample-rate/d;/^default-fragments/d;/^default-fragment-size-msec/d' /etc/pulse/daemon.conf 2>/dev/null || true
  sudo bash -c "cat >>/etc/pulse/daemon.conf" <<EOF
default-sample-rate = ${RATE}
default-fragments = ${FR}
default-fragment-size-msec = $(( FS * 1000 / RATE ))
EOF
fi

# PipeWire: set rate ở mức user (an toàn)
if systemctl --user status pipewire >/dev/null 2>&1; then
  mkdir -p ~/.config/pipewire
  echo "default.clock.rate = ${RATE}" > ~/.config/pipewire/client.conf
fi

# Nạp lại module mục tiêu ngay (runtime)
sudo modprobe "$TARGET" || true

# Khởi động lại audio stack
if systemctl --user status pipewire-pulse >/dev/null 2>&1; then
  systemctl --user start pipewire wireplumber pipewire-pulse
elif command -v pulseaudio >/dev/null 2>&1; then
  pulseaudio --start
fi

# Kiểm tra
echo "**** ALSA devices ****"; aplay -l || true
command -v pactl >/dev/null 2>&1 && { echo "**** Pulse sinks ****"; pactl list short sinks; } || true

echo "[Audio] Hoàn tất: Cấu hình cũ đã bị XÓA, cấu hình mới đã được tạo và sẽ persist qua reboot."


# -------------------------------------
# Bước 5: Thay đổi Client Rects (Font Render & Thư viện)
# -------------------------------------

# Thêm nhiều thư viện render font và cấu hình font
LIBRARIES=("libfreetype6-dev" "libfontconfig1-dev" "libharfbuzz-dev" "libicu-dev" "libxft-dev")

# Lựa chọn thư viện ngẫu nhiên
RANDOM_LIB=${LIBRARIES[$RANDOM % ${#LIBRARIES[@]}]}

echo "Cài đặt thư viện render font $RANDOM_LIB..."
if ! dpkg -l | grep -q "$RANDOM_LIB"; then
    sudo apt install -y "$RANDOM_LIB"
else
    echo "Thư viện $RANDOM_LIB đã có."
fi

# -------------------------------------
# Thông báo hoàn thành
# -------------------------------------

echo "Thông báo hoàn thành:"
echo "1. Cấu hình WebGL (GPU) đã thay đổi: Vendor ID = $RANDOM_VENDOR, Device ID = $RANDOM_DEVICE, VRAM = $RANDOM_VRAM"
echo "2. DPI và text scaling factor đã thay đổi: $RANDOM_DPI"
echo "3. Font hệ thống đã thay đổi thành: $RANDOM_FONT"
echo "4. Thiết bị âm thanh đã thay đổi thành: $TARGET (ALSA ID: $ALSA_ID)"
echo "5. Thư viện render font đã được cài đặt: $RANDOM_LIB"
echo "Bạn có thể khởi động lại VMware và kiểm tra iphey.com để thấy sự khác biệt."

# -------------------------------------
# Hoàn tất
# -------------------------------------

echo "Các thay đổi đã hoàn tất! Bạn có thể khởi động lại VMware và kiểm tra iphey.com để thấy sự khác biệt."
