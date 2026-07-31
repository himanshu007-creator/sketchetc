#!/bin/bash
sketchybar --add item wifi right \
  --set wifi \
    icon=$ICON_WIFI \
    icon.color=$CYAN \
    $POPUP_PROPS \
    popup.align=right \
    script="$PLUGIN_DIR/wifi.sh" \
  --subscribe wifi wifi_change mouse.entered mouse.exited mouse.clicked mouse.entered.global mouse.exited.global

ROW_PROPS="icon.padding_left=10 label.padding_right=12 width=$POP_W background.corner_radius=6 background.drawing=on background.color=$TRANSPARENT"

sketchybar --add item wifi.ip popup.wifi \
  --set wifi.ip icon=󰩟 icon.color=$CYAN label="…" $ROW_PROPS

sketchybar --add item wifi.toggle popup.wifi \
  --set wifi.toggle icon=$ICON_WIFI icon.color=$PINK label="Toggle Wi-Fi" $ROW_PROPS \
    script="$PLUGIN_DIR/popup_row.sh" \
    click_script="if networksetup -getairportpower en0 | grep -q ': On'; then networksetup -setairportpower en0 off; else networksetup -setairportpower en0 on; fi; sketchybar --set wifi popup.drawing=off" \
  --subscribe wifi.toggle mouse.entered mouse.exited

sketchybar --add item wifi.settings popup.wifi \
  --set wifi.settings icon=󰒓 icon.color=$CYAN label="Network Settings…" $ROW_PROPS \
    script="$PLUGIN_DIR/popup_row.sh" \
    click_script="open 'x-apple.systempreferences:com.apple.Network-Settings.extension'; sketchybar --set wifi popup.drawing=off" \
  --subscribe wifi.settings mouse.entered mouse.exited
