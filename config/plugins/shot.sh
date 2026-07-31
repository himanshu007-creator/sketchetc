#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit
if [ "$SENDER" = "mouse.clicked" ]; then
  # while recording, the icon is a stop button: opening the menu here would be
  # the one thing you do not want mid-take
  if [ -f "${TMPDIR:-/tmp}/sketchetc_recording" ]; then
    osascript -e "do shell script \"nohup '$CONFIG_DIR/plugins/shot_do.sh' stoprec > /dev/null 2>&1 &\"" >/dev/null 2>&1
    exit 0
  fi
  toggle_popup
fi
exit 0
