#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
source "$CONFIG_DIR/plugins/popup_lib.sh"
hover
close_popup_on_exit

if [ "$SENDER" = "mouse.clicked" ]; then
  sketchybar --remove '/switches.row\..*/' 2>/dev/null
  row() { # name icon label cmd
    sketchybar --add item "switches.row.$1" popup.switches \
      --set "switches.row.$1" icon="$2" icon.color=$CYAN icon.padding_left=10 \
        background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 width=$POP_W \
        label="$3" label.font="$ROW_FONT" label.padding_right=12 \
        script="$CONFIG_DIR/plugins/popup_row.sh" \
        click_script="$4; sketchybar --set switches popup.drawing=off" \
      --subscribe "switches.row.$1" mouse.entered mouse.exited
  }
  # `defaults read -g AppleInterfaceStyle` answers this in ~5ms; the equivalent
  # osascript measured ~275ms and this runs on every popup open
  DARK=false
  [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = "Dark" ] && DARK=true
  DESK=$(defaults read com.apple.finder CreateDesktop 2>/dev/null)
  row dark 󰔎 "$([ "$DARK" = "true" ] && echo 'Switch to light mode' || echo 'Switch to dark mode')" \
    "osascript -e 'tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode'"
  row desk 󰇄 "$([ "$DESK" = "0" ] || [ "$DESK" = "false" ] && echo 'Show desktop icons' || echo 'Hide desktop icons')" \
    "CUR=\$(defaults read com.apple.finder CreateDesktop 2>/dev/null); if [ \"\$CUR\" = \"0\" ] || [ \"\$CUR\" = \"false\" ]; then defaults write com.apple.finder CreateDesktop -bool true; else defaults write com.apple.finder CreateDesktop -bool false; fi; killall Finder"
  row trash 󰩹 "Empty Trash" \
    "osascript -e 'display dialog \"Empty the Trash?\" buttons {\"Cancel\",\"Empty\"} default button \"Cancel\"' | grep -q Empty && osascript -e 'tell application \"Finder\" to empty trash' && $CONFIG_DIR/plugins/notify.sh toggles Switches 'Trash emptied'"
  row saver 󱄄 "Start screensaver" "open -a ScreenSaverEngine"
  toggle_popup
  exit 0
fi
exit 0
