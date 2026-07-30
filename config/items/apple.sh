#!/bin/bash
sketchybar --add item apple left \
  --set apple \
    icon=$ICON_APPLE \
    icon.color=$PINK \
    icon.font="JetBrainsMono Nerd Font:Bold:17.0" \
    icon.padding_left=10 \
    icon.padding_right=10 \
    label.drawing=off \
    $POPUP_PROPS \
    popup.align=left \
    script="$PLUGIN_DIR/apple.sh" \
  --subscribe apple mouse.clicked mouse.entered mouse.exited mouse.entered.global mouse.exited.global

ROW_PROPS="icon.padding_left=10 label.padding_right=12 width=250 background.corner_radius=6 background.drawing=on background.color=$TRANSPARENT"

add_row() { # name icon label click_cmd [keep_open]
  local close="; sketchybar --set apple popup.drawing=off"
  [ "$5" = "keep_open" ] && close=""
  sketchybar --add item "apple.$1" popup.apple \
    --set "apple.$1" icon="$2" icon.color=$CYAN label="$3" $ROW_PROPS \
      script="$PLUGIN_DIR/popup_row.sh" \
      click_script="$4$close" \
    --subscribe "apple.$1" mouse.entered mouse.exited
}

add_row about    󰍹 "About This Mac"   "open -a 'System Information'"
add_row settings 󰒓 "System Settings…" "open -a 'System Settings'"
add_row lock     󰌾 "Lock Screen"      "pmset displaysleepnow"
add_row sleep    󰐥 "Sleep"            "pmset sleepnow"
add_row reload   󰑓 "Reload SketchyBar" "sketchybar --reload"
add_row settings2 󰒓 "Settings…" "osascript -e 'do shell script \"nohup $PLUGIN_DIR/settings_open.sh > /dev/null 2>&1 &\"'"
add_row sound    󰋋 "Notification sound…" "$PLUGIN_DIR/notify_pick.sh"

FS_LABEL=$([ -f "$CONFIG_DIR/.fs_guard_off" ] && echo "Fullscreen Guard: OFF" || echo "Fullscreen Guard: ON")
add_row fsguard 󰊓 "$FS_LABEL" 'CFG="$HOME/.config/sketchybar"; if [ -f "$CFG/.fs_guard_off" ]; then rm "$CFG/.fs_guard_off"; sketchybar --set apple.fsguard label="Fullscreen Guard: ON"; else touch "$CFG/.fs_guard_off"; sketchybar --set apple.fsguard label="Fullscreen Guard: OFF"; fi' keep_open

add_row update 󰚰 "Check for updates…" "osascript -e 'do shell script \"nohup $PLUGIN_DIR/update_now.sh > /dev/null 2>&1 &\"'"
add_row revert 󰩈 "Revert to macOS bar" "$PLUGIN_DIR/revert.sh"
sketchybar --set apple.revert icon.color=$RED label.color=$RED
