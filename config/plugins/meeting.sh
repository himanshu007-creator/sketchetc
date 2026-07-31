#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover

BIN="$CONFIG_DIR/plugins/bin/next_event"
LINK_FILE="${TMPDIR:-/tmp}/sketchybar_meetlink"

if [ "$SENDER" = "mouse.clicked" ]; then
  LINK=$(cat "$LINK_FILE" 2>/dev/null)
  [ -n "$LINK" ] && open "$LINK"
  exit 0
fi

[ -x "$BIN" ] || { sketchybar --set "$NAME" drawing=off; exit 0; }
OUT=$("$BIN" 2>/dev/null)

case "$OUT" in
  NONE|NOACCESS|"") sketchybar --set "$NAME" drawing=off; exit 0 ;;
esac

IFS='|' read -r EPOCH TITLE LINK <<< "$OUT"
MINS=$(( (EPOCH - $(date +%s)) / 60 ))
printf '%s' "$LINK" > "$LINK_FILE"

if [ "$MINS" -gt 60 ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

COLOR=$PINK
WHEN="in ${MINS}m"
[ "$MINS" -le 0 ] && WHEN="now"
if [ "$MINS" -le 2 ]; then
  COLOR=$RED
  sketchybar "${ANIM[@]}" --set "$NAME" icon.color=$RED icon.color=$PINK
fi

sketchybar --set "$NAME" drawing=on icon.color=$COLOR \
  label="$(printf '%.24s %s' "$TITLE" "$WHEN")"
