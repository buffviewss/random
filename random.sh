#!/bin/bash
set -x

# Script tự động thay đổi WebGL, Canvas, Audio và Client Rects trên Ubuntu/Lubuntu trong VMware

# -------------------------------------
# Bước 1: Tìm đường dẫn file .vmx
# -------------------------------------

echo "Tìm đường dẫn đến file .vmx của máy ảo VMware..."

# Tìm thư mục chứa máy ảo
VMWARE_VMS_DIR="$HOME/Documents/Virtual Machines"

# Tìm tất cả các file .vmx trong thư mục VMware VMs
VMX_FILE=$(find "$VMWARE_VMS_DIR" -type f -name "*.vmx" | head -n 1)

if [ -z "$VMX_FILE" ]; then
  echo "Không tìm thấy file .vmx. Vui lòng kiểm tra đường dẫn máy ảo của bạn."
  exit 1
else
  echo "Đã tìm thấy file .vmx tại: $VMX_FILE"
fi

# -------------------------------------
# Bước 2: Thay đổi WebGL (GPU) ngẫu nhiên
# -------------------------------------

echo "Thay đổi cấu hình GPU trong VMware..."
GPU_VENDOR=("0x10de" "0x1002" "0x8086")  # NVIDIA, AMD, Intel
GPU_DEVICE=("0x1eb8" "0x68e0" "0x591b")  # Các GPU khác nhau
GPU_VRAM=("134217728" "268435456" "536870912")  # 128MB, 256MB, 512MB VRAM

# Chọn ngẫu nhiên GPU và VRAM
RANDOM_VENDOR=${GPU_VENDOR[$RANDOM % ${#GPU_VENDOR[@]}]}
RANDOM_DEVICE=${GPU_DEVICE[$RANDOM % ${#GPU_DEVICE[@]}]}
RANDOM_VRAM=${GPU_VRAM[$RANDOM % ${#GPU_VRAM[@]}]}

echo "Chọn GPU: Vendor=$RANDOM_VENDOR, Device=$RANDOM_DEVICE, VRAM=$RANDOM_VRAM"
echo "svga.present = 'TRUE'" >> "$VMX_FILE"
echo "svga.vramSize = '$RANDOM_VRAM'" >> "$VMX_FILE"
echo "svga.vendorID = '$RANDOM_VENDOR'" >> "$VMX_FILE"
echo "svga.deviceID = '$RANDOM_DEVICE'" >> "$VMX_FILE"

# -------------------------------------
# Bước 3: Thêm nhiều font (Font & DPI) ngẫu nhiên
# -------------------------------------

# Danh sách các font có sẵn
FONT_LIST=("fonts-noto" "fonts-roboto" "fonts-dejavu" "fonts-liberation" "fonts-droid" "fonts-cantarell" "fonts-ubuntu" "fonts-tlwg" "fonts-linuxlibertine")

# Chọn ngẫu nhiên một số font từ danh sách
NUM_FONTS=$(($RANDOM % 3 + 3))  # Chọn từ 3 đến 5 font ngẫu nhiên
SELECTED_FONTS=()

echo "Chọn các font ngẫu nhiên để cài đặt..."

for i in $(seq 1 $NUM_FONTS); do
    FONT=${FONT_LIST[$(($RANDOM % ${#FONT_LIST[@]}))]}
    SELECTED_FONTS+=($FONT)
    echo "Chọn font: $FONT"
done

# Cài đặt các font đã chọn ngẫu nhiên
echo "Cài đặt các font ngẫu nhiên..."
sudo apt install -y ${SELECTED_FONTS[@]}

# Thay đổi DPI của màn hình ngẫu nhiên
DPI_SCALE=("1.0" "1.2" "1.5")
RANDOM_DPI=${DPI_SCALE[$RANDOM % ${#DPI_SCALE[@]}]}
echo "Thay đổi DPI của màn hình: $RANDOM_DPI"
gsettings set org.gnome.desktop.interface text-scaling-factor $RANDOM_DPI

# -------------------------------------
# Bước 4: Thay đổi Audio (Thiết bị âm thanh ảo) ngẫu nhiên
# -------------------------------------

# Tạo thiết bị âm thanh ảo ngẫu nhiên
AUDIO_MODES=("snd_dummy" "snd_hda_intel" "snd_virtuoso")
RANDOM_AUDIO=${AUDIO_MODES[$RANDOM % ${#AUDIO_MODES[@]}]}

echo "Chọn thiết bị âm thanh: $RANDOM_AUDIO"
sudo modprobe -r snd_hda_intel
sudo modprobe $RANDOM_AUDIO

# Kiểm tra thiết bị âm thanh
echo "Kiểm tra thiết bị âm thanh..."
aplay -l

# Cấu hình PulseAudio ảo
echo "Cấu hình PulseAudio..."
echo 'load-module module-null-sink sink_name=virtual_audio' | sudo tee -a /etc/pulse/default.pa

# -------------------------------------
# Bước 5: Thay đổi Client Rects (Font Render & Thư viện)
# -------------------------------------

# Cài đặt thư viện render font ngẫu nhiên
LIBRARY_LIST=("libfreetype6-dev" "libfontconfig1-dev" "libxft-dev")
RANDOM_LIB=${LIBRARY_LIST[$RANDOM % ${#LIBRARY_LIST[@]}]}

echo "Cài đặt thư viện render font: $RANDOM_LIB"
sudo apt install -y $RANDOM_LIB

# Thay đổi cấu hình font
echo "Thay đổi cấu hình font và render..."
# (Đã được thực hiện qua bước font & DPI)

# -------------------------------------
# Hoàn tất
# -------------------------------------

echo "Các thay đổi đã hoàn tất! Bạn có thể khởi động lại VMware và kiểm tra iphey.com để thấy sự khác biệt."
