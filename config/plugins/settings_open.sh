#!/bin/bash
# Opens the global Settings window (launch detached from click_scripts)
source "$CONFIG_DIR/plugins/user_config.sh"
uc_ensure
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
exec "$CONFIG_DIR/plugins/bin/settings_win" \
  "$(uc_path settings)" "$BAR_COLOR" "$ITEM_BG_COLOR" "$PINK" "$CYAN"
