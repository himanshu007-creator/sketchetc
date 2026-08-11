#!/bin/bash
# update_freq was 3, against a script that took 2.2s to run: it never finished
# before the next tick and got worse as windows accumulated. The check is now
# frontmost-only (~0.14s), and front_app_switched catches the moment that
# actually matters, so the timer is just a safety net.
sketchybar --add item fs_guard left \
  --set fs_guard drawing=off update_freq=10 script="$PLUGIN_DIR/fs_guard.sh" \
  --subscribe fs_guard front_app_switched space_change
