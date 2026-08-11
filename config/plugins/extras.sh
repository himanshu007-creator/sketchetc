#!/bin/bash
# Collapse/expand the mirrored menu bar icons, Bartender style.
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/user_config.sh"
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit
[ "$SENDER" = "mouse.clicked" ] || exit 0

LIST="$CONFIG_DIR/.cache/extras.list"
[ -f "$LIST" ] || exit 0

if [ "$(state_get extras_collapsed)" = "on" ]; then
  NEXT=off DRAW=on CHEV=$ICON_CHEV_LEFT
else
  NEXT=on DRAW=off CHEV=$ICON_CHEV_RIGHT
fi
state_set extras_collapsed "$NEXT"

# One invocation for the chevron and every icon, so the tray snaps rather than
# rippling open item by item. The list holds app NAMES for display; the items are
# extras.app.N, numbered in the same order they were written.
args=("${ANIM[@]}" --set extras.toggle icon="$CHEV")
i=0
while IFS= read -r a; do
  [ -n "$a" ] || continue
  i=$((i + 1))
  args+=(--set "extras.app.$i" drawing=$DRAW)
done < "$LIST"
sketchybar "${args[@]}" 2>/dev/null
