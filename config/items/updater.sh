#!/bin/bash
# 󰚰 update pill · hidden unless the release branch is ahead of this checkout
sketchybar --add item updater right \
  --set updater \
    width=46 \
    update_freq=1800 \
    icon=$ICON_UPDATE \
    icon.color=$PINK \
    drawing=off \
    $POPUP_PROPS \
    popup.align=right \
    script="$PLUGIN_DIR/update_check.sh" \
  --subscribe updater mouse.entered mouse.exited mouse.clicked mouse.entered.global mouse.exited.global
