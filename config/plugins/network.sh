#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
source "$CONFIG_DIR/plugins/popup_lib.sh"
hover
close_popup_on_exit

STATE="${TMPDIR:-/tmp}/sketchybar_net"

if [ "$SENDER" = "mouse.clicked" ]; then
  pop_begin network "$POP_W_WIDE"
  pop_head "Top talkers"
  i=0
  while read -r proc kb; do
    [ -n "$proc" ] || continue
    i=$((i + 1))
    pop_row "t$i" 󰀂 "$(printf '%-20.20s %8s' "$proc" "$(human_kb "$kb")")" "" "$CYAN"
  done < <(nettop -P -x -L 1 2>/dev/null | awk -F, 'NR>1 && $5+$6 > 0 {split($2,a,"."); printf "%s %d\n", a[1], ($5+$6)/1024}' | sort -k2 -rn | head -5)
  pop_empty "no traffic right now"
  pop_end
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
