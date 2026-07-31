#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit

get_vol() { osascript -e 'output volume of (get volume settings)'; }

case "$SENDER" in
  mouse.clicked)
    sketchybar --set volume.slider slider.percentage="$(get_vol)"
    # output device switcher (SoundSource's switching, free)
    sketchybar --remove '/volume.dev\..*/' 2>/dev/null
    if command -v SwitchAudioSource >/dev/null; then
      CUR=$(SwitchAudioSource -c -t output 2>/dev/null)
      i=0
      SwitchAudioSource -a -t output 2>/dev/null | while IFS= read -r dev; do
        i=$((i + 1))
        MARK="○"; MCOLOR=0x66ffffff
        [ "$dev" = "$CUR" ] && MARK="●" && MCOLOR=$PINK
        sketchybar --add item "volume.dev.$i" popup.volume \
          --set "volume.dev.$i" icon="$MARK" icon.color="$MCOLOR" icon.padding_left=12 \
            background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 width=190 \
            label="$dev" label.font="JetBrainsMono Nerd Font:Regular:11.0" label.padding_right=12 \
            script="$CONFIG_DIR/plugins/popup_row.sh" \
            click_script="SwitchAudioSource -t output -s '$dev'; sketchybar --set volume popup.drawing=off" \
          --subscribe "volume.dev.$i" mouse.entered mouse.exited
      done
    fi
    toggle_popup
    exit 0
    ;;
  mouse.scrolled)
    VOL=$(( $(get_vol) + SCROLL_DELTA ))
    [ "$VOL" -gt 100 ] && VOL=100
    [ "$VOL" -lt 0 ] && VOL=0
    osascript -e "set volume output volume $VOL"
    exit 0
    ;;
esac

VOL="$INFO"
[ -z "$VOL" ] && VOL=$(get_vol)

case $VOL in
  [7-9][0-9]|100)   ICON=$ICON_VOL_HI ;;
  [3-6][0-9])       ICON=$ICON_VOL_MID ;;
  [1-9]|[1-2][0-9]) ICON=$ICON_VOL_LO ;;
  *)                ICON=$ICON_VOL_MUTE ;;
esac

sketchybar --set "$NAME" icon="$ICON" label="${VOL}%" \
  --set volume.slider slider.percentage="$VOL"
