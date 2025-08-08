#!/bin/bash

# Các cấu hình canvas (độ phân giải + scale)
CANVAS_OPTIONS=(
  "1920x1080 1.0"
  "1920x1080 1.25"
  "1600x900 1.0"
  "1366x768 1.0"
  "1280x800 1.0"
)

# Các font giao diện (cần font đã cài sẵn)
FONT_OPTIONS=(
  "Ubuntu 11"
  "Ubuntu 12"
  "Noto Sans 11"
  "Noto Sans 12"
  "DejaVu Sans 11"
  "DejaVu Sans 12"
  "Cantarell 11"
)

# Các mức âm lượng (0-100%)
AUDIO_OPTIONS=(
  "30%"
  "50%"
  "70%"
  "80%"
  "90%"
)

# Random chọn từng cấu hình
RANDOM_CANVAS=${CANVAS_OPTIONS[$RANDOM % ${#CANVAS_OPTIONS[@]}]}
RANDOM_FONT=${FONT_OPTIONS[$RANDOM % ${#FONT_OPTIONS[@]}]}
RANDOM_AUDIO=${AUDIO_OPTIONS[$RANDOM % ${#AUDIO_OPTIONS[@]}]}

# Đổi canvas (xrandr)
RES=$(echo $RANDOM_CANVAS | awk '{print $1}')
SCALE=$(echo $RANDOM_CANVAS | awk '{print $2}')
xrandr --output $(xrandr | grep " connected" | awk '{print $1}') --mode $RES --scale $SCALE

# Đổi font giao diện (GNOME)
gsettings set org.gnome.desktop.interface font-name "$RANDOM_FONT"

# Đổi âm lượng
pactl set-sink-volume @DEFAULT_SINK@ $RANDOM_AUDIO

# Thông báo
echo "Canvas set to: $RANDOM_CANVAS"
echo "Font set to: $RANDOM_FONT"
echo "Audio volume set to: $RANDOM_AUDIO"
