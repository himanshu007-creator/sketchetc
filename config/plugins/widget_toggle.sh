#!/bin/bash
# widget_toggle.sh <key> · flip a widget with the active-count cap enforced
source "$CONFIG_DIR/plugins/user_config.sh"
uc_ensure
source "$CONFIG_DIR/colors.sh"
W="$1"
CONF="$(uc_path widgets)"
MAX=$(awk -F= '$1 == "max_active" {print $2}' "$CONF")
MAX=${MAX:-9}

if grep -q "^$W=on" "$CONF"; then
  sed -i '' "s/^$W=on/$W=off/" "$CONF"
else
  ACTIVE=$(grep -c '=on$' "$CONF")
  if [ "$ACTIVE" -ge "$MAX" ]; then
    "$CONFIG_DIR/plugins/notify.sh" toggles "Widgets" "Bar is full ($ACTIVE of $MAX active). Turn something off first."
    exit 0
  fi
  sed -i '' "s/^$W=off/$W=on/" "$CONF"
fi
sketchybar --reload
