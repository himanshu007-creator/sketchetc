#!/bin/bash
widget_on pomodoro || return 0
sketchybar --add item pomodoro right \
  --set pomodoro \
    width=dynamic \
    update_freq=1 \
    icon=$ICON_POMO \
    icon.color=$WHITE \
    label.drawing=off \
    script="$PLUGIN_DIR/pomodoro.sh" \
  --subscribe pomodoro mouse.entered mouse.exited mouse.clicked
