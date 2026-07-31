#!/bin/bash
# shared settings accessor
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/user_config.sh"
uc_ensure
SETTINGS_FILE="$(uc_path settings)"
SETTINGS_DEFAULTS="$(uc_defaults settings)"
# Prefer the value baked into the env cache by colors.sh: each awk spawn is
# ~5ms and storage_lib alone asks for several settings per plugin invocation.
setting() {
  local var="SETTING_${1//[^a-zA-Z0-9_]/_}"
  if [ -n "${!var+x}" ]; then printf '%s' "${!var}"
  else
    local v
    v=$(awk -F= -v k="$1" '$1 == k {print $2; exit}' "$SETTINGS_FILE" 2>/dev/null)
    # a setting added in a later release is missing from an older user file, so
    # fall back to the shipped default rather than reading as empty
    [ -z "$v" ] && v=$(awk -F= -v k="$1" '$1 == k {print $2; exit}' "$SETTINGS_DEFAULTS" 2>/dev/null)
    printf '%s' "$v"
  fi
}
setting_on() { [ "$(setting "$1")" != "off" ]; }   # default-on semantics
