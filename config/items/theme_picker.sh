#!/bin/bash
# 󰏘 → one-row popover: theme color dots (dynamic, includes custom themes) +
# iconset switcher + Theme Studio launcher.
sketchybar --add item theme_picker left \
  --set theme_picker \
    icon=$ICON_THEME \
    icon.color=$CYAN \
    icon.padding_left=8 icon.padding_right=8 \
    label.drawing=off \
    $POPUP_PROPS \
    popup.align=left \
    popup.horizontal=on \
    popup.height=34 \
    script="$PLUGIN_DIR/theme_picker.sh" \
  --subscribe theme_picker mouse.clicked mouse.entered mouse.exited mouse.entered.global mouse.exited.global

CURRENT_THEME=$(cat "$(uc_state .theme)" 2>/dev/null || echo vice-city)
# one dot per theme file, colored by that theme's own accent
for f in "$CONFIG_DIR"/themes/*.sh; do
  t=$(basename "$f" .sh)
  c=$(awk -F= '/^export PINK=/{print $2; exit}' "$f" | awk '{print $1}')
  [ -z "$c" ] && c=0xffffffff
  DOT=󰝦; [ "$t" = "$CURRENT_THEME" ] && DOT=󰝥
  sketchybar --add item "theme_picker.$t" popup.theme_picker \
    --set "theme_picker.$t" icon="$DOT" icon.color="$c" \
      icon.font="JetBrainsMono Nerd Font:Bold:20.0" \
      icon.padding_left=6 icon.padding_right=6 label.drawing=off background.drawing=off \
      click_script="echo $t > \$HOME/.config/sketchybar/.theme; \$HOME/.config/sketchybar/plugins/notify.sh toggles toggles sketchetc 'Theme: $t'; sketchybar --reload"
done

CURRENT_SET=$(cat "$(uc_state .iconset)" 2>/dev/null || echo nerd)
for f2 in "$CONFIG_DIR"/icons/*.sh; do
  s=$(basename "$f2" .sh)
  COLOR=0x66ffffff; [ "$s" = "$CURRENT_SET" ] && COLOR=$PINK
  sketchybar --add item "theme_picker.set_$s" popup.theme_picker \
    --set "theme_picker.set_$s" icon.drawing=off label="$s" label.color="$COLOR" \
      label.font="JetBrainsMono Nerd Font:Bold:11.0" \
      label.padding_left=8 label.padding_right=8 background.drawing=off \
      click_script="echo $s > \$HOME/.config/sketchybar/.iconset; \$HOME/.config/sketchybar/plugins/notify.sh toggles toggles sketchetc 'Icons: $s'; sketchybar --reload"
done

# Theme Studio launcher (detached: the window must outlive the click)
sketchybar --add item theme_picker.studio popup.theme_picker \
  --set theme_picker.studio icon=󰏘 icon.color=$PINK icon.padding_left=8 \
    label="studio" label.color=$PINK label.font="JetBrainsMono Nerd Font:Bold:11.0" \
    label.padding_right=8 background.drawing=off \
    click_script="sketchybar --set theme_picker popup.drawing=off; osascript -e 'do shell script \"nohup $CONFIG_DIR/plugins/theme_open.sh > /dev/null 2>&1 &\"'"
