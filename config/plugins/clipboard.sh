#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit

# capture/bump_or_store/STORE/MAX live in clip_lib.sh so the Option+V picker can
# reuse the exact same capture instead of trusting the watcher to have run
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/clip_lib.sh"

# Image height, computed once and remembered in a sidecar. sips costs ~60ms and
# an entry gets redrawn every time the popup opens, so paying it per open was
# pure waste.
img_height() { # file -> pixel height
  local h sidecar="$1.h"
  if [ -f "$sidecar" ]; then read -r h < "$sidecar"; else
    h=$(sips -g pixelHeight "$1" 2>/dev/null | awk '/pixelHeight/ {print $2}')
    [ -n "$h" ] && printf '%s' "$h" > "$sidecar" 2>/dev/null
  fi
  echo "${h:-800}"
}

build_popup() {
  # Every row used to be its own sketchybar invocation, and each costs ~41ms of
  # IPC. Eight of them meant the popup spent a third of a second before drawing.
  # Collect the whole popup into one argument list and hand it over once.
  local args=(--remove '/clipboard.row\..*/')
  args+=(--add item clipboard.row.head popup.clipboard
         --set clipboard.row.head icon.drawing=off background.drawing=off
           label="Clipboard · click to paste" label.color=$PINK label.font="$HEAD_FONT"
           label.padding_left=12 label.padding_right=12)

  local i=0 f
  while read -r f; do
    [ -n "$f" ] || continue
    i=$((i + 1))
    if [[ "$f" == *-img.png ]]; then
      local scale stamp
      scale=$(awk -v h="$(img_height "$STORE/$f")" 'BEGIN {printf "%.4f", 36 / h}')
      # macOS ships bash 3.2, which predates printf's %()T, so this stays a spawn
      stamp=$(date -r "${f%%-*}" '+%H:%M' 2>/dev/null)
      args+=(--add item "clipboard.row.$i" popup.clipboard
             --set "clipboard.row.$i" icon=" " icon.width=72 icon.padding_left=10 icon.padding_right=6
               icon.background.drawing=on
               icon.background.height=36
               icon.background.color=$TRANSPARENT
               icon.background.image="$STORE/$f"
               icon.background.image.scale="$scale"
               icon.background.image.corner_radius=4
               background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 width=340
               label="image · $stamp" label.font="$ROW_FONT" label.padding_right=12
               script="$CONFIG_DIR/plugins/popup_row.sh"
               click_script="$CONFIG_DIR/plugins/clipboard_row.sh paste '$STORE/$f'"
             --subscribe "clipboard.row.$i" mouse.entered mouse.exited)
    else
      # read builtin instead of head|tr|cut: three spawns per row added up
      local preview
      IFS= read -r -n 200 preview < "$STORE/$f" 2>/dev/null
      preview=${preview//$'\t'/ }
      preview=${preview:0:42}
      args+=(--add item "clipboard.row.$i" popup.clipboard
             --set "clipboard.row.$i" icon=󰦨 icon.color=$WHITE icon.padding_left=10
               background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 width=340
               label="$preview" label.font="$ROW_FONT" label.padding_right=12
               script="$CONFIG_DIR/plugins/popup_row.sh"
               click_script="$CONFIG_DIR/plugins/clipboard_row.sh paste '$STORE/$f'"
             --subscribe "clipboard.row.$i" mouse.entered mouse.exited)
    fi
  done < <(ls -t "$STORE" 2>/dev/null | grep -v '^\.' | grep -v '\.h$' | head -"$MAX")

  # the shortcut is the point of the widget, so say it where people will read it
  args+=(--add item clipboard.row.hint popup.clipboard
         --set clipboard.row.hint icon.drawing=off background.drawing=off
           label="Option+V opens this in any app" label.color=$PURPLE label.font="$ROW_FONT"
           label.padding_left=12 label.padding_right=12)

  sketchybar "${args[@]}" 2>/dev/null
}

case "$SENDER" in
  clip_hotkey|mouse.clicked)
    capture
    build_popup
    toggle_popup
    exit 0
    ;;
  clip_captured)
    capture
    exit 0
    ;;
  routine)
    # No capture here. capture() calls osascript, which measured 275ms, and this
    # tick runs every second: it was burning a quarter of a second of CPU per
    # second to re-detect something clip_watch already sees. clip_watch polls
    # NSPasteboard.changeCount natively at 0.15s and fires clip_captured, and
    # clipboard_choose captures synchronously when the picker opens. All this
    # tick still owes is making sure the watcher is alive, which is a kill -0.
    clip_watch_ensure
    ;;
  forced)
    clip_watch_ensure
    capture
    ;;
esac
exit 0
