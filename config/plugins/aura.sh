#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit
source "$CONFIG_DIR/plugins/aura_lib.sh"

PASSIVE_STATE="${TMPDIR:-/tmp}/sketchybar_aura_passive"

if [ "$SENDER" = "mouse.clicked" ]; then
  read -r TODAY WEEK MONTH STREAK < <(aura_stats)   # one awk pass, not four spawns
  W=250

  # One item per row: a popup item *is* a row, so a left/right split has to come
  # from the text itself. The row font is monospace, so printf padding lines the
  # numbers up into a real column.
  stat_row() { # name icon label value colour
    args+=(--add item "aura.row.$1" popup.aura
           --set "aura.row.$1" icon="$2" icon.color="$5" icon.padding_left=12 icon.padding_right=8
             background.drawing=off width=$W
             label="$(printf '%-13s %7s' "$3" "$4")"
             label.font="$ROW_FONT" label.padding_right=12)
  }

  args=(--remove '/aura.row\..*/')
  args+=(--add item aura.row.head popup.aura
         --set aura.row.head icon.drawing=off background.drawing=off
           label="Aura tracker" label.color=$PURPLE label.font="$HEAD_FONT"
           label.padding_left=12 label.padding_right=12)
  stat_row today  "$ICON_AURA" "today"   "$TODAY"  "$PINK"
  stat_row week   󰃭 "last 7 days"  "$WEEK"   "$CYAN"
  stat_row month  󰸘 "last 30 days" "$MONTH"  "$WHITE"
  stat_row streak 󰈸 "streak"       "${STREAK} d" "$ORANGE"
  args+=(--add item aura.row.open popup.aura
         --set aura.row.open icon=󰥶 icon.color=$CYAN icon.padding_left=12
           background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 width=$W
           label="Open aura…" label.font="$ROW_FONT" label.padding_right=12
           script="$CONFIG_DIR/plugins/popup_row.sh"
           click_script="sketchybar --set aura popup.drawing=off; osascript -e 'do shell script \"nohup $CONFIG_DIR/plugins/aura_open.sh > /dev/null 2>&1 &\"'"
         --subscribe aura.row.open mouse.entered mouse.exited)
  sketchybar "${args[@]}" 2>/dev/null
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
