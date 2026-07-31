#!/bin/bash
# Collapse/expand the mirrored menu bar icons, Bartender style.
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit
[ "$SENDER" = "mouse.clicked" ] || exit 0

STATE="$CONFIG_DIR/.extras_collapsed"
LIST="$CONFIG_DIR/.cache/extras.list"
[ -f "$LIST" ] || exit 0

if [ "$(cat "$STATE" 2>/dev/null)" = "on" ]; then
  NEXT=off DRAW=on CHEV=$ICON_CHEV_LEFT
else
  NEXT=on DRAW=off CHEV=$ICON_CHEV_RIGHT
fi
printf '%s' "$NEXT" > "$STATE"

# one invocation for the chevron and every alias, so the tray snaps rather than
# rippling open item by item
args=(--animate sin 12 --set extras.toggle icon="$CHEV")
while IFS= read -r a; do
  [ -n "$a" ] || continue
  args+=(--set "$a" drawing=$DRAW)
done < "$LIST"
sketchybar "${args[@]}" 2>/dev/null
