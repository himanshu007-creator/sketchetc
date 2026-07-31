#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover

STATE="${TMPDIR:-/tmp}/sketchybar_speed"

if [ "$SENDER" = "mouse.clicked" ]; then
  if [ ! -f "$STATE" ]; then
    echo "running" > "$STATE"
    sketchybar --set "$NAME" icon.color=$ORANGE label.drawing=on label="testing…"
    # detached via osascript so it survives this plugin exiting
    osascript -e "do shell script \"nohup $CONFIG_DIR/plugins/speedtest_run.sh > /dev/null 2>&1 &\""
  fi
  exit 0
fi

if [ ! -f "$STATE" ]; then
  sketchybar --set "$NAME" icon=$ICON_SPEED icon.color=$WHITE label.drawing=off
  exit 0
fi

case "$(head -1 "$STATE")" in
  running)
    sketchybar "${ANIM[@]}" --set "$NAME" icon.color=$ORANGE icon.color=$PINK
    ;;
  done*)
    IFS='|' read -r _ DOWN UP TS < "$STATE"
    if [ $(( $(date +%s) - TS )) -gt 10 ]; then
      rm -f "$STATE"
      sketchybar --set "$NAME" icon=$ICON_SPEED icon.color=$WHITE label.drawing=off
    else
      sketchybar --set "$NAME" icon=$ICON_SPEED icon.color=$CYAN label.drawing=on label="↓${DOWN} ↑${UP}"
    fi
    ;;
esac
