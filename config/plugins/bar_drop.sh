#!/bin/bash
# Keeps the bar-drop overlay running and correctly positioned.
#
# Positions come from `sketchybar --query`, never hardcoded: the shelf widget
# moves whenever widgets are toggled, so a stale rect would put the drag-out
# target over the wrong icon.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
export CONFIG_DIR
source "$CONFIG_DIR/plugins/settings_lib.sh"
source "$CONFIG_DIR/plugins/storage_lib.sh"

BIN="$CONFIG_DIR/plugins/bin/bar_drop"
LIST="$(data_dir)/shelf/list.txt"

stop() { pkill -f "plugins/bin/bar_drop" 2>/dev/null; }

query_rect() {
  sketchybar --query shelf 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)["bounding_rects"]
    r = next(iter(d.values()))
    print("%d,%d,%d,%d" % (r["origin"][0], r["origin"][1], r["size"][0], r["size"][1]))
except Exception:
    print("")' 2>/dev/null
}

case "${1:-restart}" in
  stop) stop; exit 0 ;;
esac

[ "$(setting bar_drop)" = "off" ] && { stop; exit 0; }
[ -x "$BIN" ] || exit 0

# sketchybarrc starts us while it is still creating items, so the shelf may not
# exist yet on the first query. Retry briefly rather than starting with no
# drag-out target and never recovering.
RECT=""
for _ in 1 2 3 4 5 6 7 8 9 10; do
  RECT=$(query_rect)
  [ -n "$RECT" ] && break
  sleep 0.5
done

HEIGHT=$(sketchybar --query bar 2>/dev/null | python3 -c '
import json, sys
try: print(json.load(sys.stdin).get("height", 30))
except Exception: print(30)' 2>/dev/null)

stop
sleep 0.2
nohup "$BIN" "$LIST" "$RECT" "${HEIGHT:-30}" >/dev/null 2>&1 &
