#!/bin/bash
# Opens the Theme Studio (detached-safe: call via the nohup pattern)
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/plugins/user_config.sh"
uc_ensure
source "$CONFIG_DIR/colors.sh"
mkdir -p "$USER_CONF_DIR/themes" 2>/dev/null

# Paths are handed in rather than assumed: the studio must not know where config
# lives, or it drifts from where the bar reads.
# Named flags: positions silently shifted once already and swapped the palette.
exec "$CONFIG_DIR/plugins/bin/theme_win" \
  --builtin-dir "$CONFIG_DIR/themes" \
  --user-dir    "$USER_CONF_DIR/themes" \
  --state-cli   "$CONFIG_DIR/plugins/state_cli.sh" \
  --theme       "$(state_get theme)" \
  --iconset     "$(state_get iconset)" \
  --bg          "$BAR_COLOR" \
  --panel       "$ITEM_BG_COLOR" \
  --accent1     "$PINK" \
  --accent2     "$CYAN"
