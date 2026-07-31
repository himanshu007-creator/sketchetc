#!/bin/bash
# shared interactivity helpers · source at top of every plugin.
# also loads the active theme palette ($PINK/$CYAN/...) + iconset for all plugins.
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/plugins/popup_lib.sh"

POPUP_MARKER="${TMPDIR:-/tmp}/sketchybar_open_popup"

# border glow on hover (wire only to items whose click does something)
hover() {
  case "$SENDER" in
    mouse.entered) sketchybar "${ANIM_FAST[@]}" --set "$NAME" background.border_color=$PURPLE; exit 0 ;;
    mouse.exited)  sketchybar "${ANIM_FAST[@]}" --set "$NAME" background.border_color=$TRANSPARENT; exit 0 ;;
  esac
}

# macOS-native popup behavior: popups close ONLY on outside click / other item /
# app switch · never on mere mouse-out. These senders are swallowed here.
close_popup_on_exit() {
  case "$SENDER" in
    mouse.exited.global|mouse.entered.global) exit 0 ;;
  esac
}

# exclusive toggle: close every other popup, then toggle self. The marker file
# records "<name> <click-counter-at-open>" so click_watch closes only on clicks
# that happen AFTER the popup opened (the opening click can never self-close).
toggle_popup() {
  # Three sketchybar calls at ~41ms each was most of the delay between clicking
  # an item and seeing its popup. They fold into one invocation, and the marker
  # is read with the read builtin rather than a cat|awk pipeline.
  WAS_OPEN=0 MARKED=""
  read -r MARKED _ < "$POPUP_MARKER" 2>/dev/null
  [ "$MARKED" = "$NAME" ] && WAS_OPEN=1
  rm -f "$POPUP_MARKER"
  if [ "$WAS_OPEN" -eq 0 ]; then
    sketchybar --set "/.*/" popup.drawing=off \
               "${ANIM[@]}" --set "$NAME" icon.y_offset=3 icon.y_offset=0 \
               --set "$NAME" popup.drawing=on
    read -r _ _ OPEN_CLICKS _ _ _ < <("$CONFIG_DIR/plugins/bin/mouse_info" 2>/dev/null || echo "0 0 0 0 0 0")
    echo "$NAME ${OPEN_CLICKS:-0}" > "$POPUP_MARKER"
  else
    sketchybar --set "/.*/" popup.drawing=off
  fi
}

close_all_popups() {
  sketchybar --set "/.*/" popup.drawing=off
  rm -f "$POPUP_MARKER"
}

# human-readable size from a KB value: 823K · 12.4M · 1.2G · 1.1T
human_kb() {
  awk -v k="$1" 'BEGIN {
    if (k >= 1073741824)      printf "%.1fT", k/1073741824
    else if (k >= 1048576)    printf "%.1fG", k/1048576
    else if (k >= 1024)       printf "%.1fM", k/1024
    else                      printf "%dK", k
  }'
}

# standard styling for dynamic popup rows
ROW_FONT="JetBrainsMono Nerd Font:Regular:12.0"
HEAD_FONT="JetBrainsMono Nerd Font:Bold:13.0"
