#!/bin/bash
set -e

echo "[FP-HARDEN] Fingerprint Randomizer cho Ubuntu/Lubuntu 24.04"

# Phát hiện môi trường
if [ -x "$(command -v lxqt-config)" ]; then
    GUI_ENV="Lubuntu"
else
    GUI_ENV="Ubuntu"
fi
echo "Đang chạy trên $GUI_ENV."

# =============================
# 1. WEBGL – GPU & Mesa Random
# =============================
VMX_FILE="$HOME/.vmware/your_vm.vmx"
GPU_VENDOR=("0x10de" "0x8086" "0x1002" "0x1414" "0x1043")
GPU_DEVICE=("0x1eb8" "0x1d01" "0x6810" "0x0000" "0x6780")
GPU_VRAM=("134217728" "67108864" "268435456" "536870912")
RANDOM_VENDOR=${GPU_VENDOR[$RANDOM % ${#GPU_VENDOR[@]}]}
RANDOM_DEVICE=${GPU_DEVICE[$RANDOM % ${#GPU_DEVICE[@]}]}
RANDOM_VRAM=${GPU_VRAM[$RANDOM % ${#GPU_VRAM[@]}]}

mkdir -p "$(dirname "$VMX_FILE")"
cat > "$VMX_FILE" <<EOF
svga.present = "TRUE"
svga.vramSize = "$RANDOM_VRAM"
svga.vendorID = "$RANDOM_VENDOR"
svga.deviceID = "$RANDOM_DEVICE"
EOF
echo "[WebGL] GPU ID/VRAM thay đổi: $RANDOM_VENDOR / $RANDOM_DEVICE / $RANDOM_VRAM"

sudo apt update
sudo apt install -y mesa-utils mesa-vulkan-drivers

# Random shader precision bằng config Mesa
MESA_CONF_DIR="$HOME/.drirc"
mkdir -p "$MESA_CONF_DIR"
cat > "$MESA_CONF_DIR/drirc" <<EOF
<?xml version="1.0"?>
<!DOCTYPE driinfo SYSTEM "driinfo.dtd">
<driconf>
 <device>
  <application name="all">
    <option name="disable_glsl_line_smooth" value="$(shuf -e true false -n1)"/>
    <option name="vblank_mode" value="$(shuf -e 0 1 2 -n1)"/>
    <option name="mesa_glthread" value="$(shuf -e true false -n1)"/>
  </application>
 </device>
</driconf>
EOF
echo "[WebGL] Mesa shader precision/random config đã tạo."

# =============================
# 2. CANVAS – Font, DPI, Hinting
# =============================
DPI_SCALE=("1.0" "1.25" "1.5" "1.75" "2.0")
RANDOM_DPI=${DPI_SCALE[$RANDOM % ${#DPI_SCALE[@]}]}
gsettings set org.gnome.desktop.interface text-scaling-factor "$RANDOM_DPI" || true
echo "[Canvas] DPI scaling set: $RANDOM_DPI"

# Random font
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
FONTS_LIST=("Roboto" "Open Sans" "Lato" "Montserrat" "Source Sans Pro" "Merriweather" "Noto Sans" "Noto Serif" "Ubuntu" "Fira Sans" "Poppins" "Raleway" "Oswald" "PT Sans" "Work Sans")
RANDOM_FONT=${FONTS_LIST[$RANDOM % ${#FONTS_LIST[@]}]}
if ! fc-list | grep -qi "$RANDOM_FONT"; then
    sudo apt install -y fontconfig subversion
    FONT_URL="https://github.com/google/fonts/trunk/ofl/$(echo "$RANDOM_FONT" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
    svn export --force "$FONT_URL" "$FONT_DIR/$RANDOM_FONT" || true
    fc-cache -fv >/dev/null
fi

# Fontconfig áp dụng font default
mkdir -p ~/.config/fontconfig
cat > ~/.config/fontconfig/fonts.conf <<EOF
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <match target="pattern">
    <edit name="family" mode="assign">
      <string>$RANDOM_FONT</string>
    </edit>
  </match>
</fontconfig>
EOF
fc-cache -fv >/dev/null
echo "[Canvas] Font default đổi thành: $RANDOM_FONT"

# Hinting + Subpixel
HINTING_OPTIONS=("true" "false")
ANTIALIAS_OPTIONS=("true" "false")
SUBPIXEL_OPTIONS=("rgb" "bgr" "vrgb" "vbgr" "none")
RANDOM_HINTING=${HINTING_OPTIONS[$RANDOM % ${#HINTING_OPTIONS[@]}]}
RANDOM_ANTIALIAS=${ANTIALIAS_OPTIONS[$RANDOM % ${#ANTIALIAS_OPTIONS[@]}]}
RANDOM_SUBPIXEL=${SUBPIXEL_OPTIONS[$RANDOM % ${#SUBPIXEL_OPTIONS[@]}]}

cat > ~/.config/fontconfig/render.conf <<EOF
<?xml version='1.0'?>
<!DOCTYPE fontconfig SYSTEM 'fonts.dtd'>
<fontconfig>
  <match target="font">
    <edit name="hinting" mode="assign"><bool>$RANDOM_HINTING</bool></edit>
    <edit name="antialias" mode="assign"><bool>$RANDOM_ANTIALIAS</bool></edit>
    <edit name="rgba" mode="assign"><const>$RANDOM_SUBPIXEL</const></edit>
  </match>
</fontconfig>
EOF
fc-cache -fv >/dev/null
echo "[ClientRects] Render: hinting=$RANDOM_HINTING, antialias=$RANDOM_ANTIALIAS, subpixel=$RANDOM_SUBPIXEL"

# =============================
# 3. AUDIO – Driver & DSP Filter
# =============================
sudo apt install -y pulseaudio-utils sox libsox-fmt-all ladspa-sdk
AUDIO_DRIVERS=("snd_ens1371" "snd_hda_intel" "snd_usb_audio")
TARGET_AUDIO=${AUDIO_DRIVERS[$RANDOM % ${#AUDIO_DRIVERS[@]}]}
sudo modprobe -r snd_ens1371 snd_hda_intel snd_usb_audio || true
sudo modprobe "$TARGET_AUDIO" || true

# Tạo DSP filter noise nhỏ để thay đổi fingerprint
FILTER_LEVEL=$(shuf -i 1-3 -n1)
mkdir -p ~/.config/pulse
cat > ~/.config/pulse/default.pa <<EOF
.include /etc/pulse/default.pa
load-module module-ladspa-sink sink_name=dsp_out plugin=noise source_port=output control=$FILTER_LEVEL
set-default-sink dsp_out
EOF

pulseaudio -k || true
pulseaudio --start
echo "[Audio] Driver: $TARGET_AUDIO | DSP noise level: $FILTER_LEVEL"

# =============================
# 4. Kết thúc
# =============================
echo "-----------------------------------"
echo "TÓM TẮT:"
echo "WebGL: Vendor=$RANDOM_VENDOR, Device=$RANDOM_DEVICE, VRAM=$RANDOM_VRAM"
echo "Canvas: DPI=$RANDOM_DPI, Font=$RANDOM_FONT"
echo "Audio: Driver=$TARGET_AUDIO, DSP noise=$FILTER_LEVEL"
echo "ClientRects: hinting=$RANDOM_HINTING, antialias=$RANDOM_ANTIALIAS, subpixel=$RANDOM_SUBPIXEL"
echo "Hãy reboot VM để các thay đổi WebGL/Mesa áp dụng hoàn toàn."
