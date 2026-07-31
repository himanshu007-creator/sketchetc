#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit

STATE="${TMPDIR:-/tmp}/sketchybar_net"

if [ "$SENDER" = "mouse.clicked" ]; then
  args=(--remove '/network.top\..*/'
        --add item network.top.head popup.network
        --set network.top.head icon.drawing=off background.drawing=off label="Top talkers"
          label.color=$CYAN label.font="$HEAD_FONT" label.padding_left=12 label.padding_right=12)
  i=0
  while read -r proc kb; do
    [ -n "$proc" ] || continue
    i=$((i + 1))
    args+=(--add item "network.top.$i" popup.network
           --set "network.top.$i" icon.drawing=off background.drawing=off
             label="$(printf '%-18.18s %7s' "$proc" "$(human_kb "$kb")")"
             label.font="$ROW_FONT" label.padding_left=12 label.padding_right=12)
  done < <(nettop -P -x -L 1 2>/dev/null | awk -F, 'NR>1 && $5+$6 > 0 {split($2,a,"."); printf "%s %d\n", a[1], ($5+$6)/1024}' | sort -k2 -rn | head -5)
  sketchybar "${args[@]}" 2>/dev/null
  toggle_popup
  exit 0
fi

read -r IB OB < <(netstat -I en0 -b 2>/dev/null | tail -1 | awk '{print $7, $10}')
NOW=$(date +%s)
read -r PIB POB PT < <(cat "$STATE" 2>/dev/null || echo "$IB $OB $NOW")
echo "$IB $OB $NOW" > "$STATE"
DT=$((NOW - PT)); [ "$DT" -lt 1 ] && DT=1

DOWN=$(human_kb $(( (IB - PIB) / DT / 1024 )))
UP=$(human_kb $(( (OB - POB) / DT / 1024 )))

sketchybar --set "$NAME" label="↓$DOWN ↑$UP"
