#!/bin/bash
# Update nudge: compares the installed checkout against its release branch.
# Hidden unless there is something to install (and silent when offline or when
# the config was copied rather than cloned).
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit
source "$CONFIG_DIR/plugins/settings_lib.sh"

APP=$(cd "$CONFIG_DIR/.." 2>/dev/null && pwd -P)   # config is a symlink into the checkout
APP=$(dirname "$(readlink "$HOME/.config/sketchybar" 2>/dev/null || echo "$CONFIG_DIR")")
CHANNEL=$(setting channel); CHANNEL=${CHANNEL:-production}
STATE="$CONFIG_DIR/.update_state"

git -C "$APP" rev-parse --git-dir >/dev/null 2>&1 || { sketchybar --set "$NAME" drawing=off; exit 0; }

if [ "$SENDER" = "mouse.clicked" ]; then
  read -r BEHIND LOCAL REMOTE < <(cat "$STATE" 2>/dev/null || echo "0 - -")
  sketchybar --remove '/updater.row\..*/' 2>/dev/null
  sketchybar --add item updater.row.head popup.updater \
    --set updater.row.head icon.drawing=off background.drawing=off \
      label="Update available · $BEHIND commit(s)" label.color=$PINK label.font="$HEAD_FONT" \
      label.padding_left=12 label.padding_right=12
  row() { # name icon label cmd
    sketchybar --add item "updater.row.$1" popup.updater \
      --set "updater.row.$1" icon="$2" icon.color=$CYAN icon.padding_left=10 \
        background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 width=280 \
        label="$3" label.font="$ROW_FONT" label.padding_right=12 \
        script="$CONFIG_DIR/plugins/popup_row.sh" \
        click_script="$4; sketchybar --set updater popup.drawing=off" \
      --subscribe "updater.row.$1" mouse.entered mouse.exited
  }
  row now  󰚰 "Update now" "osascript -e 'do shell script \"nohup $CONFIG_DIR/plugins/update_now.sh quiet > /dev/null 2>&1 &\"'"
  row notes 󰋽 "What's new" "osascript -e 'do shell script \"nohup $CONFIG_DIR/plugins/release_open.sh remote > /dev/null 2>&1 &\"'"
  row skip 󰅖 "Skip this version" "echo '$REMOTE' > $CONFIG_DIR/.update_skip; sketchybar --set updater drawing=off"
  toggle_popup
  exit 0
fi

# routine: fetch quietly, count how far behind we are
git -C "$APP" fetch --quiet origin "$CHANNEL" 2>/dev/null || { sketchybar --set "$NAME" drawing=off; exit 0; }
BEHIND=$(git -C "$APP" rev-list --count "HEAD..origin/$CHANNEL" 2>/dev/null || echo 0)
LOCAL=$(git -C "$APP" rev-parse --short HEAD 2>/dev/null)
REMOTE=$(git -C "$APP" rev-parse --short "origin/$CHANNEL" 2>/dev/null)
echo "$BEHIND $LOCAL $REMOTE" > "$STATE"

if [ "${BEHIND:-0}" -gt 0 ] && [ "$(cat "$CONFIG_DIR/.update_skip" 2>/dev/null)" != "$REMOTE" ]; then
  sketchybar --set "$NAME" drawing=on label="$BEHIND" icon.color=$PINK label.color=$PINK
  # notify once per remote head
  if [ ! -f "$CONFIG_DIR/.update_notified_$REMOTE" ]; then
    for old in "$CONFIG_DIR"/.update_notified_*; do
      [ -e "$old" ] && [ "$old" != "$CONFIG_DIR/.update_notified_$REMOTE" ] && rm -f "$old"
    done
    touch "$CONFIG_DIR/.update_notified_$REMOTE"
    "$CONFIG_DIR/plugins/notify.sh" update "sketchetc" "$BEHIND update(s) ready · click the 󰚰 pill"
  fi
else
  sketchybar --set "$NAME" drawing=off
fi
