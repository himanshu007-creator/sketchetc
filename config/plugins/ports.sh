#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit

# every user listener in the dev range (1024-9999), minus macOS system noise;
# deduped by port (IPv4/IPv6 double entries)
listeners() {
  lsof -iTCP -sTCP:LISTEN -P -n 2>/dev/null \
    | awk '$1 !~ /^(ControlCe|rapportd|sharingd|AirPlay|mDNSRespo|identitys|launchd)/ {
        split($9, a, ":"); p = a[length(a)]
        if (p >= 1024 && p <= 9999 && !seen[p]++) print p, $2, $1
      }' | sort -un
}

if [ "$SENDER" = "mouse.clicked" ]; then
  sketchybar --remove '/ports.row\..*/' 2>/dev/null
  sketchybar --add item ports.row.head popup.ports \
    --set ports.row.head icon.drawing=off background.drawing=off label="Dev servers (click to kill)" \
      label.color=$CYAN label.font="$HEAD_FONT" label.padding_left=12 label.padding_right=12
  i=0
  listeners | while read -r port pid comm; do
    i=$((i + 1))
    sketchybar --add item "ports.row.$i" popup.ports \
      --set "ports.row.$i" icon=$ICON_PORTS icon.color=$ORANGE icon.padding_left=10 \
        background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 $POP_W_WIDE \
        label=":$port · $comm (pid $pid)" label.font="$ROW_FONT" label.padding_right=12 \
        script="$CONFIG_DIR/plugins/popup_row.sh" \
        click_script="kill $pid && $CONFIG_DIR/plugins/notify.sh ports ports 'Dev servers' 'Stopped $comm on port $port'; sketchybar --set ports popup.drawing=off" \
      --subscribe "ports.row.$i" mouse.entered mouse.exited
  done
  toggle_popup
  exit 0
fi

COUNT=$(listeners | wc -l | tr -d ' ')
if [ "$COUNT" -gt 0 ]; then
  sketchybar --set "$NAME" drawing=on label="$COUNT"
else
  sketchybar --set "$NAME" drawing=off
fi
