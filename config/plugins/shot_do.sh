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
  local info bin="$CONFIG_DIR/plugins/bin/pbinfo"
  if [ -x "$bin" ]; then info=$("$bin" 2>/dev/null)
  else info=$(osascript -e 'clipboard info' 2>/dev/null)
  fi
  case "$info" in
    *PNGf*|*TIFF*|*png*|*tiff*) return 0 ;;
    *) return 1 ;;
  esac
}

REC_STATE="${TMPDIR:-/tmp}/sketchetc_recording"

# --- screen recording -------------------------------------------------------
# screencapture -v records until it is interrupted, and finalises the file on
# SIGINT. There is no interactive region picker for video, so "record area" runs
# the native image selector once, throws the png away and reuses the rectangle
# macOS remembers, falling back to the whole screen if that is unreadable.
start_recording() {
  local out region=""
  out="$DIR/rec-$(date +%Y%m%d-%H%M%S).mov"
  if [ "$1" = "area" ]; then
    local tmp; tmp=$(mktemp -t shotsel).png
    screencapture -i "$tmp" 2>/dev/null
    [ -s "$tmp" ] || { rm -f "$tmp"; exit 0; }     # selection cancelled
    rm -f "$tmp"
    region=$(defaults read com.apple.screencapture "last-selection" 2>/dev/null | \
      awk -F'[ =;]+' '/Height/{h=$3} /Width/{w=$3} /X/{x=$3} /Y/{y=$3} END{if (w>0 && h>0) printf "%d,%d,%d,%d", x, y, w, h}')
  fi
  if [ -n "$region" ]; then
    screencapture -v -R"$region" "$out" >/dev/null 2>&1 &
  else
    screencapture -v "$out" >/dev/null 2>&1 &
  fi
  echo "$! $out" > "$REC_STATE"
  sketchybar --set shot icon=$ICON_REC icon.color=$RED label="REC" label.color=$RED label.drawing=on 2>/dev/null
  notify "Recording · click the shot icon to stop"
}

stop_recording() {
  [ -f "$REC_STATE" ] || return 1
  read -r pid out < "$REC_STATE"
  rm -f "$REC_STATE"
  kill -INT "$pid" 2>/dev/null
  # give screencapture a moment to finalise the container
  for _ in 1 2 3 4 5 6 7 8; do [ -s "$out" ] && break; sleep 0.4; done
  sketchybar --set shot icon=$ICON_SHOT icon.color=$CYAN label.drawing=off 2>/dev/null
  if [ -s "$out" ]; then
    notify "Recording saved to $(basename "$DIR")"
  else
    notify "Recording produced no file, check Screen Recording permission"
  fi
  return 0
}

case "$1" in
  record)     start_recording screen; exit 0 ;;
  recordarea) start_recording area;   exit 0 ;;
  stoprec)    stop_recording;         exit 0 ;;
  color)
    # native eyedropper: same loupe macOS uses, no Screen Recording grant needed
    OUT_HEX=$("$CONFIG_DIR/plugins/bin/pick_color" 2>/dev/null) || exit 0
    [ -z "$OUT_HEX" ] && exit 0
    printf '%s' "${OUT_HEX%% *}" | pbcopy
    sketchybar --trigger clip_captured 2>/dev/null
    notify "${OUT_HEX%% *} copied"
    exit 0 ;;
esac

# Interactive captures can take as long as the user needs, so callers launch
# this script detached; it must not be tied to a click_script's lifetime.
case "$1" in
  area)     screencapture -i "$OUT" ;;
  areaclip) screencapture -ic ;;
  areatext) screencapture -i "$OUT" ;;   # OCR'd below, the png is scratch
  window)   screencapture -iw "$OUT" ;;
  full)     screencapture -x "$OUT" ;;
  timer)    screencapture -T 5 -x "$OUT" ;;
  *) exit 0 ;;
esac

if [ "$1" = "areatext" ]; then
  # Text beats a picture of text: this is how a screen ends up in an LLM, a
  # terminal or a search box. All on-device, via Vision.
  if [ -s "$OUT" ]; then
    TEXT=$("$CONFIG_DIR/plugins/bin/ocr" "$OUT" 2>/dev/null)
    rm -f "$OUT"
    if [ -n "$TEXT" ]; then
      printf '%s' "$TEXT" | pbcopy
      sketchybar --trigger clip_captured 2>/dev/null
      LINES=$(printf '%s\n' "$TEXT" | wc -l | tr -d ' ')
      notify "Copied $LINES line(s) of text, ready to paste"
    else
      notify "No text found in that selection"
    fi
  fi
elif [ "$1" = "areaclip" ]; then
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
