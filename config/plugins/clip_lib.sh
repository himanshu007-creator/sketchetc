#!/bin/bash
# Shared clipboard capture. Lives here rather than inside clipboard.sh because the
# Option+V picker needs to capture the pasteboard synchronously before it lists the
# store: relying on the clip_watch poller alone means a copy made a moment ago can
# be missing from the picker.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/plugins/storage_lib.sh"

STORE="$(clip_dir)"
mkdir -p "$STORE"
MAX=5   # keep it tight: only the last five copies

# if content matches an EXISTING entry, bump it to the top (newest); otherwise
# store as a new entry. Catches every copy source: ⌘C, menu copy, web copies.
bump_or_store() { # hash tmpfile suffix
  local hash="$1" tmp="$2" suffix="$3" f
  for f in "$STORE"/*."${suffix##*.}"; do
    [ -f "$f" ] || continue
    if [ "$(md5 -q "$f")" = "$hash" ]; then
      touch "$f"                       # re-copy of an old entry: newest again
      rm -f "$tmp"
      return
    fi
  done
  mv "$tmp" "$STORE/$(date +%s)-$suffix"
  ls -t "$STORE" | grep -v '^\.' | tail -n +$((MAX + 1)) | while read -r old; do rm -f "$STORE/$old"; done
}

capture() {
  local info hash f
  info=$(osascript -e 'clipboard info' 2>/dev/null)
  [ -z "$info" ] && return
  if [[ "$info" == *"PNGf"* || "$info" == *"TIFF"* ]]; then
    command -v pngpaste >/dev/null || return
    f="$STORE/.candidate.png"
    pngpaste "$f" 2>/dev/null || return
    hash=$(md5 -q "$f")
    bump_or_store "$hash" "$f" "img.png"
  else
    local text
    text=$(pbpaste 2>/dev/null | head -c 100000)
    [ -z "$text" ] && return
    hash=$(printf '%s' "$text" | md5 -q)
    f="$STORE/.candidate.txt"
    printf '%s' "$text" > "$f"
    bump_or_store "$hash" "$f" "txt.txt"
  fi
}

clip_watch_ensure() {
  # The watcher is what imports native screenshots and keeps the bar's history
  # live. It was only ever started when the bar loaded, so if it died you got no
  # history until the next reload. kill -0 is cheap enough to check every tick.
  local pid_file="${TMPDIR:-/tmp}/sketchybar_clip_watch.pid" bin="$CONFIG_DIR/plugins/bin/clip_watch"
  [ -x "$bin" ] || return 0
  if [ -f "$pid_file" ] && kill -0 "$(cat "$pid_file" 2>/dev/null)" 2>/dev/null; then
    return 0
  fi
  nohup "$bin" "$STORE" > /dev/null 2>&1 &
  echo $! > "$pid_file"
}
