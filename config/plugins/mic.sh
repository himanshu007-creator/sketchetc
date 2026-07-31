#!/bin/bash
# Mic mute. State comes from CoreAudio via bin/mic (~39ms); the osascript
# equivalent costs ~275ms and this runs on every tick.
source "$CONFIG_DIR/plugins/hover.sh"
hover

BIN="$CONFIG_DIR/plugins/bin/mic"
[ -x "$BIN" ] || exit 0

if [ "$SENDER" = "mouse.clicked" ]; then
  STATE=$("$BIN" toggle)
  [ "$STATE" = "muted" ] && MSG="Microphone muted" || MSG="Microphone live"
  "$CONFIG_DIR/plugins/notify.sh" toggles "Mic" "$MSG"
else
  STATE=$("$BIN" get)
fi

if [ "$STATE" = "muted" ]; then
  sketchybar "${ANIM_FAST[@]}" --set "$NAME" icon=$ICON_MIC_OFF icon.color=$RED
else
  sketchybar "${ANIM_FAST[@]}" --set "$NAME" icon=$ICON_MIC_ON icon.color=$WHITE
fi
