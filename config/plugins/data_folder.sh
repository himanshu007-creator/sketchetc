#!/bin/bash
# data_folder.sh [pick|show] · choose where sketchetc keeps your data.
# Picking a folder that already holds sketchetc data adopts it (so reinstalling
# and pointing at the same folder restores your journal and aura history);
# otherwise existing data is moved across once.
source "$CONFIG_DIR/plugins/user_config.sh"
uc_ensure
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
export CONFIG_DIR
source "$CONFIG_DIR/plugins/storage_lib.sh"

case "${1:-pick}" in
  show) data_dir; exit 0 ;;
esac

OLD=$(data_dir)
NEW=$(osascript -e 'POSIX path of (choose folder with prompt "Where should sketchetc keep your journal, aura history and clipboard?")' 2>/dev/null)
[ -z "$NEW" ] && exit 0
NEW="${NEW%/}"

# a folder the user picks may itself be the data folder, or the parent of one
if ! data_has_content "$NEW" && [ -d "$NEW/sketchetc" ] && data_has_content "$NEW/sketchetc"; then
  NEW="$NEW/sketchetc"
fi

write_setting() { # key value
  if grep -q "^$1=" "$(uc_path settings)"; then
    sed -i '' "s|^$1=.*|$1=$2|" "$(uc_path settings)"
  else
    echo "$1=$2" >> "$(uc_path settings)"
  fi
}

if data_has_content "$NEW"; then
  # ---- adopt: existing history stays exactly where it is ----
  write_setting data_dir "$NEW"
  data_ensure
  DAYS=$(find "$NEW/journal" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  "$CONFIG_DIR/plugins/notify.sh" toggles "sketchetc" "Found existing data · restored $DAYS journal entries"
elif [ -d "$OLD" ] && data_has_content "$OLD" && [ "$OLD" != "$NEW" ]; then
  # ---- move: carry current data over, once ----
  mkdir -p "$NEW"
  for sub in journal aura clipboard; do
    if [ -d "$OLD/$sub" ]; then
      mkdir -p "$NEW/$sub"
      # journal entries are chflagged immutable; unlock, copy, relock
      find "$OLD/$sub" -type f -exec chflags nouchg {} \; 2>/dev/null
      cp -R "$OLD/$sub/." "$NEW/$sub/" 2>/dev/null
      find "$NEW/$sub" -name '*.md' -path '*/journal/2*' -exec chflags uchg {} \; 2>/dev/null
      rm -rf "$OLD/$sub"
    fi
  done
  write_setting data_dir "$NEW"
  data_ensure
  "$CONFIG_DIR/plugins/notify.sh" toggles "sketchetc" "Data folder moved to $(basename "$NEW")"
else
  # ---- fresh ----
  write_setting data_dir "$NEW"
  data_ensure
  "$CONFIG_DIR/plugins/notify.sh" toggles "sketchetc" "Data folder set to $(basename "$NEW")"
fi

sketchybar --reload
