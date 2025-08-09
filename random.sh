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
DPI_SCALE=("1.0" "1.2" "1.5" "1.8" "2.0" "1.3" "1.6" "1.4")
RANDOM_DPI=${DPI_SCALE[$RANDOM % ${#DPI_SCALE[@]}]}

echo "Thay đổi DPI của màn hình với scaling factor $RANDOM_DPI..."
gsettings set org.gnome.desktop.interface text-scaling-factor "$RANDOM_DPI"

# -------------------------------------
# Bước 3: Random hóa Font chữ
# -------------------------------------

# Các font chữ phổ biến để chọn ngẫu nhiên
FONTS=("Noto" "Liberation Sans" "DejaVu Sans" "Ubuntu" "Arial" "Times New Roman" "Courier New" "Comic Sans MS" "Georgia" "Verdana")

# Lựa chọn font ngẫu nhiên
RANDOM_FONT=${FONTS[$RANDOM % ${#FONTS[@]}]}

echo "Thay đổi font chữ hệ thống thành $RANDOM_FONT..."

# Cài đặt font nếu chưa có
if ! dpkg -l | grep -q "$RANDOM_FONT"; then
    echo "Đang cài đặt font $RANDOM_FONT..."
    sudo apt install -y fonts-$RANDOM_FONT
else
    echo "Font $RANDOM_FONT đã được cài đặt."
fi

# Cập nhật font hệ thống (sử dụng gnome hoặc tùy hệ thống của bạn)
if [ "$GUI_ENV" = "Ubuntu" ]; then
    gsettings set org.gnome.desktop.interface font-name "$RANDOM_FONT"
else
    # Đối với Lubuntu, sử dụng LXQt để thay đổi font
    lxqt-config-appearance -set-font "$RANDOM_FONT"
fi

# -------------------------------------
# Bước 4: Thay đổi Audio (Thiết bị âm thanh ảo)
# -------------------------------------

# Các thiết bị âm thanh ảo để random
AUDIO_DEVICES=("snd_hda_intel" "snd_dummy" "snd_ens1371" "snd_usb_audio" "snd_pcm_oss" "snd_atiixp" "snd_emu10k1" "snd_intel8x0" "snd_via82xx")

# Lựa chọn thiết bị âm thanh ngẫu nhiên
RANDOM_AUDIO=${AUDIO_DEVICES[$RANDOM % ${#AUDIO_DEVICES[@]}]}

echo "Tạo thiết bị âm thanh ảo ($RANDOM_AUDIO)..."
sudo modprobe -r snd_hda_intel
sudo modprobe "$RANDOM_AUDIO"

# Kiểm tra thiết bị âm thanh
echo "Kiểm tra thiết bị âm thanh..."
aplay -l

# Cấu hình PulseAudio ảo
echo "Cấu hình PulseAudio..."
echo 'load-module module-null-sink sink_name=virtual_audio' | sudo tee -a /etc/pulse/default.pa

# -------------------------------------
# Bước 5: Thay đổi Client Rects (Font Render & Thư viện)
# -------------------------------------

# Cài đặt thư viện render font nếu chưa có
if ! dpkg -l | grep -q "libfreetype6-dev"; then
    echo "Đang cài đặt thư viện render font..."
    sudo apt install -y libfreetype6-dev
else
    echo "Thư viện render font đã có."
fi

# -------------------------------------
# Hoàn tất
# -------------------------------------

echo "Các thay đổi đã hoàn tất! Bạn có thể khởi động lại VMware và kiểm tra iphey.com để thấy sự khác biệt."
