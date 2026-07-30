#!/bin/bash
# shot_do.sh area|areaclip|window|full|timer · CleanShot-lite via screencapture
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
export CONFIG_DIR
source "$CONFIG_DIR/plugins/settings_lib.sh"

DIR=$(setting shot_dir)
case "$DIR" in ""|DESKTOP) DIR="$HOME/Desktop" ;; esac
mkdir -p "$DIR" 2>/dev/null
OUT="$DIR/shot-$(date +%Y%m%d-%H%M%S).png"
sleep 0.5   # let our own popup finish closing, or it ends up in the shot

notify() { "$CONFIG_DIR/plugins/notify.sh" shot "Screenshot" "$1"; }

# an image on the pasteboard is how we tell a real capture from a cancelled one
clipboard_has_image() {
  case "$(osascript -e 'clipboard info' 2>/dev/null)" in
    *PNGf*|*TIFF*) return 0 ;;
    *) return 1 ;;
  esac
}

# Interactive captures can take as long as the user needs, so callers launch
# this script detached; it must not be tied to a click_script's lifetime.
case "$1" in
  area)     screencapture -i "$OUT" ;;
  areaclip) screencapture -ic ;;
  window)   screencapture -iw "$OUT" ;;
  full)     screencapture -x "$OUT" ;;
  timer)    screencapture -T 5 -x "$OUT" ;;
  *) exit 0 ;;
esac

if [ "$1" = "areaclip" ]; then
  # Esc during an interactive capture copies nothing, so only claim success when
  # something actually landed on the pasteboard
  if clipboard_has_image; then
    sketchybar --trigger clip_captured 2>/dev/null
    notify "Snip ready to paste"
  fi
elif [ -s "$OUT" ]; then
  if setting_on shot_to_clipboard; then
    # heredoc rather than -e: this script is itself launched through
    # `osascript -e 'do shell script "..."'`, and the guillemets in «class PNGf»
    # do not survive that many rounds of shell quoting
    osascript <<EOF 2>/dev/null
set the clipboard to (read (POSIX file "$OUT") as «class PNGf»)
EOF
    if clipboard_has_image; then
      # refresh the bar's history now rather than waiting for the next poll
      sketchybar --trigger clip_captured 2>/dev/null
      notify "Snip ready to paste"
    else
      notify "Snip saved to $(basename "$DIR"), clipboard copy failed"
    fi
  else
    # clipboard copy is off, so the pasteboard will never carry this image and
    # clip_watch deliberately ignores our own shot-*.png. Put it in the history
    # directly, otherwise the snip would be missing from Option+V entirely.
    source "$CONFIG_DIR/plugins/clip_lib.sh"
    cp "$OUT" "$STORE/.candidate.png" 2>/dev/null \
      && bump_or_store "$(md5 -q "$OUT")" "$STORE/.candidate.png" "img.png"
    sketchybar --update 2>/dev/null
    notify "Snip saved to $(basename "$DIR")"
  fi
else
  rm -f "$OUT"
fi
