#!/bin/bash
# release_open.sh [sinceVersion|remote] · shows RELEASES.md in a themed window
source "$CONFIG_DIR/plugins/user_config.sh"
uc_ensure
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
APP=$(dirname "$(readlink "$HOME/.config/sketchybar" 2>/dev/null || echo "$CONFIG_DIR")")
NOTES="$APP/RELEASES.md"

if [ "$1" = "remote" ]; then
  # peek at the notes on the release branch without pulling
  CH=$(awk -F= '$1=="channel"{print $2}' "$(uc_path settings)" 2>/dev/null); CH=${CH:-production}
  TMP="${TMPDIR:-/tmp}/sketchetc_remote_notes.md"
  git -C "$APP" show "origin/$CH:RELEASES.md" > "$TMP" 2>/dev/null && NOTES="$TMP"
  SINCE=""
else
  SINCE="${1:-}"
fi

[ -f "$NOTES" ] || exit 0
exec "$CONFIG_DIR/plugins/bin/release_win" "$NOTES" "$SINCE" \
  "$BAR_COLOR" "$ITEM_BG_COLOR" "$PINK" "$CYAN"
