#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit
source "$CONFIG_DIR/plugins/aura_lib.sh"
source "$CONFIG_DIR/plugins/popup_lib.sh"

PASSIVE_STATE="${TMPDIR:-/tmp}/sketchybar_aura_passive"

if [ "$SENDER" = "mouse.clicked" ]; then
  read -r TODAY WEEK MONTH STREAK < <(aura_stats)   # one awk pass, not four spawns

  pop_begin aura "$POP_W"
  pop_head "Aura tracker"
  pop_kv today  "$ICON_AURA" "today"        "$TODAY"    "$PINK"
  pop_kv week   󰃭 "last 7 days"  "$WEEK"     "$CYAN"
  pop_kv month  󰸘 "last 30 days" "$MONTH"    "$WHITE"
  pop_kv streak 󰈸 "streak"       "${STREAK} d" "$ORANGE"
  pop_row open  󰥶 "Open aura…" \
    "sketchybar --set aura popup.drawing=off; osascript -e 'do shell script \"nohup $CONFIG_DIR/plugins/aura_open.sh > /dev/null 2>&1 &\"'"
  pop_end
  toggle_popup
  exit 0
fi

# passive accrual: every 30 min tick, meaningful typing earns a trickle
read -r _ _ CLICKS _ _ KEYS < <("$CONFIG_DIR/plugins/bin/mouse_info")
read -r PKEYS PCLICKS < <(cat "$PASSIVE_STATE" 2>/dev/null || echo "$KEYS $CLICKS")
echo "$KEYS $CLICKS" > "$PASSIVE_STATE"
DK=$((KEYS - PKEYS))
if [ "$DK" -gt 500 ] && [ "$(aura_today)" -lt 2000 ]; then
  aura_add 5 passive "$DK" $((CLICKS - PCLICKS)) 0 0
fi
sketchybar --set "$NAME" drawing=on label="$(aura_today)"
