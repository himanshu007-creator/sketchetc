#!/bin/bash
# state_cli.sh get|set|clear <key> [value]
#
# sketchybar click_scripts are shell strings, not sourced functions, so they
# cannot call state_set directly. This is the one seam through which they reach
# the state machine, which keeps `echo something > some/path` out of click
# handlers: that pattern is exactly how theme selection ended up writing to a
# file nothing read.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/plugins/user_config.sh"
uc_ensure

case "${1:-}" in
  get)   state_get "$2" ;;
  set)   state_set "$2" "$3" ;;
  clear) state_clear "$2" ;;
  *)     echo "usage: state_cli.sh get|set|clear <key> [value]" >&2; exit 2 ;;
esac
