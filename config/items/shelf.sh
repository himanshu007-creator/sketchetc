#!/bin/bash
# 󰀼 drop shelf · park files here, drag them out somewhere else
widget_on shelf || return 0
source "$CONFIG_DIR/plugins/storage_lib.sh"
sketchybar --add event shelf_changed
sketchybar --add event shelf_clicked
sketchybar --add item shelf right \
  --set shelf \
    icon=$ICON_SHELF \
    icon.color=$CYAN \
    icon.padding_left=7 icon.padding_right=5 \
    label.padding_right=7 \
    label.drawing=off \
    update_freq=30 \
    script="$PLUGIN_DIR/shelf.sh" \
  --subscribe shelf shelf_changed shelf_clicked mouse.clicked mouse.entered mouse.exited
