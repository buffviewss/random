#!/usr/bin/env bash
# Randomize system UI fonts and default audio output device
# Compatible with Ubuntu 24.04 (GNOME) and Lubuntu 24.04 (LXQt)
# Usage: bash randomize_font_audio.sh

set -euo pipefail

log() { printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$*"; }
warn() { printf "[%s] WARN: %s\n" "$(date +'%H:%M:%S')" "$*" >&2; }
err()  { printf "[%s] ERROR: %s\n" "$(date +'%H:%M:%S')" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# --- Optional installation of reputable font and audio packages (Ubuntu/Lubuntu 24.04) ---
DRY_RUN=false
OPT_INSTALL_FONTS=false
OPT_INSTALL_AUDIO=false
SKIP_APT_UPDATE=false
FONT_WHITELIST=""
MONO_WHITELIST=""
AUDIO_WHITELIST=""


usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --install-fonts           Install a curated set of reputable font packages from Ubuntu repo
  --install-audio           Install audio stack utilities (PipeWire/PulseAudio tools, ALSA, Bluetooth)
  --install-all             Shortcut for --install-fonts --install-audio
  --font-whitelist "A,B"    Comma-separated font families allowed for UI/mono
  --mono-whitelist  "A,B"    Comma-separated monospace families (fallbacks to --font-whitelist if omitted)
  --audio-whitelist "S1,S2" Comma-separated sink names allowed (pactl sink names)
  --dry-run                 Show the commands that would run, without making changes
  --no-update               Skip 'sudo apt-get update' before installs
  -h, --help                Show this help and exit

Environment variables:
  FONT_WHITELIST       Comma-separated UI font families (e.g., "Ubuntu,Roboto,DejaVu Sans")
  MONO_WHITELIST       Comma-separated monospace families (e.g., "JetBrains Mono,Fira Code")
  AUDIO_WHITELIST      Comma-separated pactl sink names to choose from

Examples:
  $0 --install-fonts           # Install fonts, then randomize font + audio sink
  $0 --install-audio --dry-run # Preview audio packages that would be installed
  $0                            # Just randomize current fonts and default audio sink
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --install-fonts) OPT_INSTALL_FONTS=true ;;
      --install-audio) OPT_INSTALL_AUDIO=true ;;
      --install-all)   OPT_INSTALL_FONTS=true; OPT_INSTALL_AUDIO=true ;;
      --font-whitelist)
        shift; FONT_WHITELIST="${1:-}" ;;
      --mono-whitelist)
        shift; MONO_WHITELIST="${1:-}" ;;
      --audio-whitelist)
        shift; AUDIO_WHITELIST="${1:-}" ;;
      --dry-run)       DRY_RUN=true ;;
      --no-update)     SKIP_APT_UPDATE=true ;;
      -h|--help)       usage; exit 0 ;;
      *) warn "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
  done
}

run_cmd() {
  # Echo and run a command unless DRY_RUN=true
  if $DRY_RUN; then
    echo "+ $*"
  else
    eval "$@"
  fi
}

apt_update() {
  if $SKIP_APT_UPDATE; then
    log "Skipping apt-get update (per --no-update)"
    return 0
  fi
  if $DRY_RUN; then
    echo "+ sudo apt-get update"
    return 0
  fi
  if ! have sudo; then err "sudo is required to install packages"; return 1; fi
  sudo apt-get update
}

apt_install_pkgs() {
  # Install packages passed as arguments; continue on failures, log them
  local pkgs=("$@")
  if [ ${#pkgs[@]} -eq 0 ]; then return 0; fi
  if $DRY_RUN; then
    echo "+ sudo apt-get install -y --no-install-recommends ${pkgs[*]}"
    return 0
  fi
  if ! have sudo; then err "sudo is required to install packages"; return 1; fi
  set +e
  sudo apt-get install -y --no-install-recommends "${pkgs[@]}"
  local rc=$?
  set -e
  if [ $rc -ne 0 ]; then
    warn "Bulk install had errors; retrying per-package..."
    for p in "${pkgs[@]}"; do
      set +e; sudo apt-get install -y --no-install-recommends "$p"; rc=$?; set -e
      [ $rc -eq 0 ] || warn "Failed to install: $p"
    done
  fi
}

install_fonts() {
  log "Installing curated font packages..."
  apt_update || return 1
  local pkgs=(
    fonts-ubuntu
    fonts-ubuntu-console
    fonts-dejavu
    fonts-liberation
    fonts-cantarell
    fonts-noto-core
    fonts-noto-cjk
    fonts-noto-color-emoji
    fonts-roboto
    fonts-firacode
    fonts-jetbrains-mono
    fonts-cascadia-code
  )
  apt_install_pkgs "${pkgs[@]}" || true
  if have fc-cache; then
    run_cmd fc-cache -f
  fi
}

install_audio() {
  log "Installing audio stack utilities..."
  apt_update || return 1
  local pkgs=(
    pipewire
    pipewire-pulse
    wireplumber

    libspa-0.2-bluetooth
    pavucontrol
    alsa-utils
    pulseaudio-utils
    bluez
  )
  apt_install_pkgs "${pkgs[@]}" || true
  warn "You may need to log out/in or restart your session for audio stack changes to take full effect."
}


pick_random_line() {
  # Read lines from stdin, pick 1 random line
  if have shuf; then
    shuf -n 1
  else
    # Fallback if shuf is not available
    awk 'BEGIN{srand()} {a[NR]=$0} END{if(NR>0){print a[int(rand()*NR)+1]}}'
  fi
}
split_csv() {
  # Print each comma-separated token on a new line, trimming spaces
  printf "%s" "$1" | tr ',' '\n' | sed 's/^[[:space:]]\+//; s/[[:space:]]\+$//' | sed '/^$/d'
}

list_installed_font_families() {
  # Args: filter (e.g., ":spacing=100" for monospace)
  local filter="${1:-}"
  fc-list "$filter" -f '%{family}\n' 2>/dev/null | \
    tr ',' '\n' | sed 's/^[[:space:]]\+//; s/[[:space:]]\+$//' | sed '/^$/d' | \
    awk 'length($0)>2{print}' | sort -fu
}

choose_from_whitelist() {
  # Args: whitelist_csv, filter
  local whitelist_csv="$1"; local filter="${2:-}"
  local installed allow choice
  installed=$(list_installed_font_families "$filter") || return 1
  if [ -z "$whitelist_csv" ]; then
    return 1
  fi
  # Intersect whitelist with installed
  # Use temp files for compatibility (avoid process substitution)
  local _wl _inst
  _wl=$(mktemp) ; _inst=$(mktemp)
  split_csv "$whitelist_csv" >"$_wl"
  printf "%s\n" "$installed" >"$_inst"
  choice=$(awk 'NR==FNR{a[$0]=1;next} a[$0]' "$_wl" "$_inst" | pick_random_line)
  rm -f "$_wl" "$_inst"
  printf "%s\n" "$choice"
}


choose_random_family() {
  # Parameters: filter (empty for all; e.g., ":spacing=100" for monospace)
  local filter="${1:-}"
  if ! have fc-list; then
    err "fc-list is required to enumerate installed fonts. Please install fontconfig (sudo apt install fontconfig)."
    return 1
  fi
  # Collect families, split comma-separated aliases, trim, de-duplicate
  # Avoid generic family aliases like 'sans', 'serif', 'monospace' by filtering length>2 heuristically
  local families
  families=$(fc-list "$filter" -f '%{family}\n' 2>/dev/null | \
    tr ',' '\n' | sed 's/^\s\+//; s/\s\+$//' | sed '/^$/d' | \
    awk 'length($0)>2{print}' | sort -fu)
  if [ -z "$families" ]; then
    return 1
  fi
  printf "%s\n" "$families" | pick_random_line
}

get_gnome_font_size() {
  # Extract the integer size from a gsettings font entry; default to 11
  local schema_key="$1"
  local val size
  if have gsettings; then
    if val=$(gsettings get $schema_key 2>/dev/null); then
      size=$(printf "%s" "$val" | grep -Eo '[0-9]+' | tail -n1 || true)
      [ -n "$size" ] && { printf "%s\n" "$size"; return 0; }
    fi
  fi
  printf "11\n"
}

set_gnome_fonts() {
  # Set interface/document/monospace/titlebar fonts on GNOME
  local ui_family="$1"; local mono_family="$2";
  local ui_size mono_size title_size
  ui_size=$(get_gnome_font_size org.gnome.desktop.interface font-name)
  mono_size=$(get_gnome_font_size org.gnome.desktop.interface monospace-font-name)
  title_size=$(get_gnome_font_size org.gnome.desktop.wm.preferences titlebar-font)

  [ -z "$ui_size" ] && ui_size=11
  [ -z "$mono_size" ] && mono_size=$ui_size
  [ -z "$title_size" ] && title_size=$ui_size

  if ! have gsettings; then
    warn "gsettings not found; cannot set GNOME fonts."
    return 1
  fi

  log "Setting GNOME fonts: UI='${ui_family} ${ui_size}', Document='${ui_family} ${ui_size}', Monospace='${mono_family} ${mono_size}', Titlebar='${ui_family} ${title_size}'"
  gsettings set org.gnome.desktop.interface font-name "${ui_family} ${ui_size}"
  gsettings set org.gnome.desktop.interface document-font-name "${ui_family} ${ui_size}"
  gsettings set org.gnome.desktop.interface monospace-font-name "${mono_family} ${mono_size}"
  gsettings set org.gnome.desktop.wm.preferences titlebar-font "${ui_family} ${title_size}"
}

ensure_lxqt_general_section() {
  local cfg="$1"
  if ! grep -q '^\[General\]' "$cfg" 2>/dev/null; then
    printf "\n[General]\n" >>"$cfg"
  fi
}

get_lxqt_font_size() {
  # Read size from font="Family,Size" in [General]
  local cfg="$1"; local key="$2" # key: font or monoFont
  local line size
  if [ -f "$cfg" ]; then
    line=$(awk -v sec="General" -v key="$key" '
      $0 ~ /^\[/ { in=($0=="["sec"]") }
      in && $0 ~ "^"key"=" { print; exit }
    ' "$cfg") || true
    if [ -n "$line" ]; then
      size=$(printf "%s" "$line" | sed -E 's/.*,(\s*)([0-9]+).*/\2/')
      if [ -n "$size" ]; then printf "%s\n" "$size"; return 0; fi
    fi
  fi
  printf "10\n"
}

set_lxqt_fonts() {
  # Set LXQt fonts in ~/.config/lxqt/lxqt.conf
  local ui_family="$1"; local mono_family="$2";
  local cfg="$HOME/.config/lxqt/lxqt.conf"
  mkdir -p "$(dirname "$cfg")"
  touch "$cfg"
  cp -f "$cfg" "$cfg.bak.$(date +%Y%m%d-%H%M%S)"

  local ui_size mono_size
  ui_size=$(get_lxqt_font_size "$cfg" font)
  mono_size=$(get_lxqt_font_size "$cfg" monoFont)

  ensure_lxqt_general_section "$cfg"

  # Update or insert keys within [General]
  awk -v ui_fam="$ui_family" -v mono_fam="$mono_family" -v ui_size="$ui_size" -v mono_size="$mono_size" '
    BEGIN { in=0; seen_font=0; seen_monofont=0 }
    /^\[/ { if(in && !printed_tail){ if(!seen_font) print "font=\"" ui_fam "," ui_size "\""; if(!seen_monofont) print "monoFont=\"" mono_fam "," mono_size "\""; printed_tail=1 } in = ($0=="[General]"); print; next }
    {
      if(in) {
        if($0 ~ /^font=/) { print "font=\"" ui_fam "," ui_size "\""; seen_font=1; next }
        if($0 ~ /^monoFont=/) { print "monoFont=\"" mono_fam "," mono_size "\""; seen_monofont=1; next }
      }
      print
    }
    END {
      if(!printed_tail) {
        if(!in) { print "[General]" }
        if(!seen_font) print "font=\"" ui_fam "," ui_size "\""
        if(!seen_monofont) print "monoFont=\"" mono_fam "," mono_size "\""
      }
    }
  ' "$cfg" >"$cfg.tmp" && mv "$cfg.tmp" "$cfg"

  log "Updated LXQt fonts in $cfg. You may need to log out and log back in for changes to fully apply."
}

randomize_fonts() {
  local de="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
  local de_lc="$(printf "%s" "$de" | tr '[:upper:]' '[:lower:]')"

  local ui_family mono_family
  # Always prefer whitelist; if not installed/empty, abort per yêu cầu "chỉ random trong whitelist"
  ui_family=$(choose_from_whitelist "$FONT_WHITELIST" "")
  if [ -z "$ui_family" ]; then
    err "No UI font selected. Ensure --font-whitelist contains installed families (check with fc-list)."
    return 1
  fi
  if [ -n "$MONO_WHITELIST" ]; then
    mono_family=$(choose_from_whitelist "$MONO_WHITELIST" ":spacing=100")
  else
    mono_family=$(choose_from_whitelist "$FONT_WHITELIST" ":spacing=100")
  fi
  [ -n "$mono_family" ] || mono_family="${ui_family}"

  if printf "%s" "$de_lc" | grep -q "gnome"; then
    set_gnome_fonts "$ui_family" "$mono_family" || warn "Failed to set GNOME fonts."
  elif printf "%s" "$de_lc" | grep -q "lxqt\|lubuntu"; then
    set_lxqt_fonts "$ui_family" "$mono_family" || warn "Failed to set LXQt fonts."
  else
    # Try GNOME first; if fails, try LXQt config edit as fallback
    if ! set_gnome_fonts "$ui_family" "$mono_family"; then
      set_lxqt_fonts "$ui_family" "$mono_family" || warn "Unknown desktop; fonts may not be changed."
    fi
  fi
}

randomize_audio_output() {
  if ! have pactl; then
    err "pactl is required to control audio sinks. Install: sudo apt install pulseaudio-utils (PipeWire provides pactl via pipewire-pulse)."
    return 1
  fi

  local current sinks sink_count new_sink
  current=$(pactl get-default-sink 2>/dev/null || true)
  sinks=$(pactl list short sinks 2>/dev/null | awk '{print $2}')
  if [ -n "$AUDIO_WHITELIST" ]; then
    # Filter sinks to the whitelist (avoid process substitution)
    tmp_wl=$(mktemp)
    split_csv "$AUDIO_WHITELIST" >"$tmp_wl"
    sinks=$(printf "%s\n" "$sinks" | awk 'NR==FNR{a[$0]=1;next} a[$0]' "$tmp_wl" -)
    rm -f "$tmp_wl"
  fi
  if [ -z "$sinks" ]; then
    err "No audio sinks found."
    return 1
  fi

  # Build list excluding current
  local candidates
  candidates=$(printf "%s\n" "$sinks" | awk -v cur="$current" 'NF && $0!=cur')

  if [ -z "$candidates" ]; then
    warn "Only one audio output sink detected ('${current}'); cannot switch."
    return 0
  fi

  new_sink=$(printf "%s\n" "$candidates" | pick_random_line)
  if [ -z "$new_sink" ]; then
    warn "Failed to choose a random sink."
    return 1
  fi

  log "Switching default audio sink to: $new_sink"
  pactl set-default-sink "$new_sink"

  # Move active streams to new sink
  local input_ids
  input_ids=$(pactl list short sink-inputs 2>/dev/null | awk '{print $1}')
  if [ -n "$input_ids" ]; then
    while IFS= read -r id; do
      [ -n "$id" ] && pactl move-sink-input "$id" "$new_sink" || true
    done <<< "$input_ids"
    log "Moved active audio streams to $new_sink"
  fi
}

main() {
  parse_args "$@"

  if $OPT_INSTALL_FONTS; then
    install_fonts || warn "Font installation encountered issues."
  fi
  if $OPT_INSTALL_AUDIO; then
    install_audio || warn "Audio installation encountered issues."
  fi

  log "Randomizing fonts..."
  randomize_fonts || warn "Font randomization encountered issues."

  log "Randomizing audio output device..."
  randomize_audio_output || warn "Audio output switch encountered issues."

  log "Done."
}

main "$@"

