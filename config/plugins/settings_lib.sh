#!/bin/bash
# shared settings accessor
SETTINGS_FILE="${CONFIG_DIR:-$HOME/.config/sketchybar}/settings.conf"
# Prefer the value baked into the env cache by colors.sh: each awk spawn is
# ~5ms and storage_lib alone asks for several settings per plugin invocation.
setting() {
  local var="SETTING_${1//[^a-zA-Z0-9_]/_}"
  if [ -n "${!var+x}" ]; then printf '%s' "${!var}"
  else awk -F= -v k="$1" '$1 == k {print $2; exit}' "$SETTINGS_FILE" 2>/dev/null
  fi
}
setting_on() { [ "$(setting "$1")" != "off" ]; }   # default-on semantics
