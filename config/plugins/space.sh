#!/bin/bash
source "$CONFIG_DIR/colors.sh"
if [ "$SENDER" = "mouse.clicked" ]; then
  # ctrl+1..4 via "Switch to Desktop N" hotkeys (key codes 18-21)
  KEY=$((17 + ${NAME#space.}))
  osascript -e "tell application \"System Events\" to key code $KEY using control down"
  exit 0
fi

sketchybar "${ANIM_FAST[@]}" --set "$NAME" icon.highlight="$SELECTED" \
  background.color=$([ "$SELECTED" = "true" ] && echo $ITEM_BG_COLOR || echo $TRANSPARENT)
