#!/bin/bash
# Drop shelf: the window does the drag handling, this keeps the bar in sync.
source "$CONFIG_DIR/plugins/hover.sh"
hover
source "$CONFIG_DIR/plugins/storage_lib.sh"

LIST="$(data_dir)/shelf/list.txt"
mkdir -p "$(dirname "$LIST")" 2>/dev/null

count() { [ -f "$LIST" ] && grep -c . "$LIST" 2>/dev/null || echo 0; }

if [ "$SENDER" = "mouse.clicked" ] || [ "$SENDER" = "shelf_clicked" ]; then
  # one window at a time: a second click closes the one that is open
  if pgrep -f "bin/shelf_win" >/dev/null 2>&1; then
    pkill -f "bin/shelf_win"
  else
    osascript -e "do shell script \"nohup '$CONFIG_DIR/plugins/bin/shelf_win' '$LIST' > /dev/null 2>&1 &\"" >/dev/null 2>&1
  fi
  exit 0
fi

# the shelf icon moves when widgets are toggled, so re-place the overlay
[ "$SENDER" = "shelf_changed" ] && "$CONFIG_DIR/plugins/bar_drop.sh" restart >/dev/null 2>&1 &

N=$(count)
if [ "${N:-0}" -gt 0 ]; then
  sketchybar --set "$NAME" label="$N" label.drawing=on label.color=$CYAN icon.color=$CYAN
else
  sketchybar --set "$NAME" label.drawing=off icon.color=$WHITE
fi
