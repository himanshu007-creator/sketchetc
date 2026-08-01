#!/bin/bash
# Opens the Theme Studio (detached-safe: call via the nohup pattern)
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/plugins/user_config.sh"
uc_ensure
source "$CONFIG_DIR/colors.sh"
mkdir -p "$USER_CONF_DIR/themes" 2>/dev/null

# Paths are handed in rather than assumed: the studio must not know where config
# lives, or it drifts from where the bar reads.
exec "$CONFIG_DIR/plugins/bin/theme_win" \
  "$CONFIG_DIR/themes" \
  "$USER_CONF_DIR/themes" \
  "$CONFIG_DIR/plugins/state_cli.sh" \
  "$(state_get theme)" \
  "$(state_get iconset)" \
  "$BAR_COLOR" "$ITEM_BG_COLOR" "$PINK" "$CYAN"
