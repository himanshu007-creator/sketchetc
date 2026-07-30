#!/bin/bash
widget_on clipboard || return 0
source "$CONFIG_DIR/plugins/storage_lib.sh"
sketchybar --add event clip_hotkey
sketchybar --add event clip_captured
sketchybar --add item clipboard right \
  --set clipboard \
    update_freq=1 \
    icon=$ICON_CLIP \
    icon.color=$WHITE \
    label.drawing=off \
    $POPUP_PROPS \
    popup.align=right \
    script="$PLUGIN_DIR/clipboard.sh" \
  --subscribe clipboard clip_hotkey clip_captured mouse.entered mouse.exited mouse.clicked mouse.entered.global mouse.exited.global

source "$CONFIG_DIR/plugins/clip_lib.sh"
clip_watch_ensure
