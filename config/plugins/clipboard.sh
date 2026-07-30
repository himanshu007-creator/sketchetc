#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit

# capture/bump_or_store/STORE/MAX live in clip_lib.sh so the Option+V picker can
# reuse the exact same capture instead of trusting the watcher to have run
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/clip_lib.sh"

build_popup() {
  sketchybar --remove '/clipboard.row\..*/' 2>/dev/null
  sketchybar --add item clipboard.row.head popup.clipboard \
    --set clipboard.row.head icon.drawing=off background.drawing=off \
      label="Clipboard · click to paste" label.color=$PINK label.font="$HEAD_FONT" \
      label.padding_left=12 label.padding_right=12
  i=0
  ls -t "$STORE" | grep -v '^\.' | head -5 | while read -r f; do
    i=$((i + 1))
    if [[ "$f" == *-img.png ]]; then
      # small always-visible thumbnail on the left (scale computed per image)
      IMG_H=$(sips -g pixelHeight "$STORE/$f" 2>/dev/null | awk '/pixelHeight/ {print $2}')
      SCALE=$(awk -v h="${IMG_H:-800}" 'BEGIN {printf "%.4f", 36 / h}')
      sketchybar --add item "clipboard.row.$i" popup.clipboard \
        --set "clipboard.row.$i" icon=" " icon.width=72 icon.padding_left=10 icon.padding_right=6 \
          icon.background.drawing=on \
          icon.background.height=36 \
          icon.background.color=$TRANSPARENT \
          icon.background.image="$STORE/$f" \
          icon.background.image.scale="$SCALE" \
          icon.background.image.corner_radius=4 \
          background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 width=340 \
          label="image · $(date -r "$STORE/$f" '+%H:%M')" label.font="$ROW_FONT" label.padding_right=12 \
          script="$CONFIG_DIR/plugins/popup_row.sh" \
          click_script="$CONFIG_DIR/plugins/clipboard_row.sh paste '$STORE/$f'" \
        --subscribe "clipboard.row.$i" mouse.entered mouse.exited
    else
      PREVIEW=$(head -c 300 "$STORE/$f" | tr '\n\t' '  ' | cut -c1-42)
      sketchybar --add item "clipboard.row.$i" popup.clipboard \
        --set "clipboard.row.$i" icon=󰦨 icon.color=$WHITE icon.padding_left=10 \
          background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 width=340 \
          label="$PREVIEW" label.font="$ROW_FONT" label.padding_right=12 \
          script="$CONFIG_DIR/plugins/popup_row.sh" \
          click_script="$CONFIG_DIR/plugins/clipboard_row.sh paste '$STORE/$f'" \
        --subscribe "clipboard.row.$i" mouse.entered mouse.exited
    fi
  done

  # the shortcut is the point of the widget, so say it where people will read it
  sketchybar --add item clipboard.row.hint popup.clipboard \
    --set clipboard.row.hint icon.drawing=off background.drawing=off \
      label="Option+V opens this in any app" label.color=$PURPLE label.font="$ROW_FONT" \
      label.padding_left=12 label.padding_right=12
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
  routine|forced)
    clip_watch_ensure
    capture
    ;;
esac
exit 0
