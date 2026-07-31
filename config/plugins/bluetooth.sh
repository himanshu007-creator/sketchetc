#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit

if [ "$SENDER" = "mouse.clicked" ]; then
  sketchybar --remove '/bluetooth.row\..*/' 2>/dev/null
  sketchybar --add item bluetooth.row.head popup.bluetooth \
    --set bluetooth.row.head icon.drawing=off background.drawing=off \
      label="Paired devices (click to connect)" label.color=$CYAN label.font="$HEAD_FONT" \
      label.padding_left=12 label.padding_right=12
  # battery percentages where macOS reports them
  BATT=$(system_profiler SPBluetoothDataType 2>/dev/null | awk -F': ' '
    /^ {10}[A-Za-z0-9]/ {dev=$1; gsub(/^ +|:$/,"",dev)}
    /Battery Level/ {print dev "|" $2}')
  i=0
  while IFS=, read -r addr rest; do
    NAME_D=$(echo "$rest" | sed 's/^ *//')
    [ -z "$addr" ] && continue
    i=$((i + 1))
    CONN=○; COLOR=0x66ffffff
    blueutil --is-connected "$addr" 2>/dev/null | grep -q 1 && CONN=● && COLOR=$PINK
    PCT=$(echo "$BATT" | awk -F'|' -v n="$NAME_D" '$1 == n {print " · " $2}' | head -1)
    sketchybar --add item "bluetooth.row.$i" popup.bluetooth \
      --set "bluetooth.row.$i" icon="$CONN" icon.color="$COLOR" icon.padding_left=10 \
        background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 $POP_W_WIDE \
        label="${NAME_D}${PCT}" label.font="$ROW_FONT" label.padding_right=12 \
        script="$CONFIG_DIR/plugins/popup_row.sh" \
        click_script="if blueutil --is-connected $addr | grep -q 1; then blueutil --disconnect $addr; else blueutil --connect $addr; fi; sketchybar --set bluetooth popup.drawing=off" \
      --subscribe "bluetooth.row.$i" mouse.entered mouse.exited
  done < <(blueutil --paired --format csv 2>/dev/null | awk -F, '{print $1 "," $2}' | sed 's/address: //; s/ name: "\(.*\)"/\1/' )
  toggle_popup
  exit 0
fi

N=$(blueutil --connected 2>/dev/null | wc -l | tr -d ' ')
if [ "$N" -gt 0 ]; then
  sketchybar --set "$NAME" label.drawing=on label="$N"
else
  sketchybar --set "$NAME" label.drawing=off
fi
