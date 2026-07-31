#!/bin/bash
widget_on shot || return 0
sketchybar --add item shot right \
  --set shot \
    width=32 \
    icon=$ICON_SHOT \
    icon.color=$CYAN \
    icon.padding_left=7 icon.padding_right=7 \
    label.drawing=off \
    $POPUP_PROPS \
    popup.align=right \
    script="$PLUGIN_DIR/shot.sh" \
  --subscribe shot mouse.entered mouse.exited mouse.clicked mouse.entered.global mouse.exited.global

shot_row() { # name icon label flags dest
  sketchybar --add item "shot.$1" popup.shot \
    --set "shot.$1" icon="$2" icon.color=$CYAN icon.padding_left=10 \
      background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 $POP_W \
      label="$3" label.font="JetBrainsMono Nerd Font:Regular:12.0" label.padding_right=12 \
      script="$CONFIG_DIR/plugins/popup_row.sh" \
      click_script="sketchybar --set shot popup.drawing=off; osascript -e 'do shell script \"nohup $CONFIG_DIR/plugins/shot_do.sh $4 > /dev/null 2>&1 &\"'" \
    --subscribe "shot.$1" mouse.entered mouse.exited
}
shot_row area  󰩭 "Capture area"             area
shot_row clip  󰅍 "Capture area → clipboard" areaclip
shot_row text  󰚞 "Capture area → text (OCR)"  areatext
shot_row win   󰖯 "Capture window"           window
shot_row full  󰹑 "Full screen"              full
shot_row timer 󰔛 "Full screen in 5s"        timer
shot_row rec   󰑊 "Record screen"             record
shot_row reca  󰻂 "Record area"               recordarea
shot_row color 󰸌 "Pick a colour"             color
