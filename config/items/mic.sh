#!/bin/bash
# 󰍬 microphone mute · one click to cut the input, state visible at a glance
widget_on mic || return 0
sketchybar --add item mic right \
  --set mic \
    width=dynamic \
    icon=$ICON_MIC_ON \
    icon.color=$WHITE \
    icon.padding_left=7 icon.padding_right=7 \
    label.drawing=off \
    update_freq=5 \
    script="$PLUGIN_DIR/mic.sh" \
  --subscribe mic mouse.clicked mouse.entered mouse.exited
