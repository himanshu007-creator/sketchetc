#!/bin/bash
# Shared clipboard capture. Lives here rather than inside clipboard.sh because the
# Option+V picker needs to capture the pasteboard synchronously before it lists the
# store: relying on the clip_watch poller alone means a copy made a moment ago can
# be missing from the picker.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/plugins/storage_lib.sh"

STORE="$(clip_dir)"
mkdir -p "$STORE"
# how many copies to keep. Was a hardcoded 5, which is the main reason people
# keep a dedicated clipboard manager around.
MAX=$(awk -F= '$1 == "clip_max" {print $2; exit}' "$CONFIG_DIR/settings.conf" 2>/dev/null)
case "$MAX" in ''|*[!0-9]*) MAX=20 ;; esac

# entries only: .h sidecars carry cached image heights and dotfiles are scratch
clip_entries() { ls -t "$STORE" 2>/dev/null | grep -v '^\.' | grep -vE '\.(h|md5)$'; }

# if content matches an EXISTING entry, bump it to the top (newest); otherwise
# store as a new entry. Catches every copy source: ⌘C, menu copy, web copies.
# each entry's hash is remembered in a sidecar. Re-hashing every stored file on
# every capture meant up to MAX md5 spawns per copy.
entry_hash() { # file -> md5
  local h sidecar="$1.md5"
  if [ -f "$sidecar" ] && [ "$sidecar" -nt "$1" ]; then read -r h < "$sidecar"
  else h=$(md5 -q "$1" 2>/dev/null); printf '%s' "$h" > "$sidecar" 2>/dev/null
  fi
  echo "$h"
}

bump_or_store() { # hash tmpfile suffix
  local hash="$1" tmp="$2" suffix="$3" f
  for f in "$STORE"/*."${suffix##*.}"; do
    [ -f "$f" ] || continue
    case "$f" in *.md5|*.h) continue ;; esac
    if [ "$(entry_hash "$f")" = "$hash" ]; then
      touch "$f"                       # re-copy of an old entry: newest again
      rm -f "$tmp"
      return
    fi
  done
  local dest="$STORE/$(date +%s)-$suffix"
  mv "$tmp" "$dest"
  printf '%s' "$hash" > "$dest.md5" 2>/dev/null   # known already, never re-hash it
  # trim to MAX, taking each entry's sidecars with it
  clip_entries | tail -n +$((MAX + 1)) | while read -r old; do
    rm -f "$STORE/$old" "$STORE/$old.h" "$STORE/$old.md5"
  done
}

# pasteboard types, via the helper when built (~21ms) rather than osascript (~275ms)
pb_types() {
  local bin="$CONFIG_DIR/plugins/bin/pbinfo"
  if [ -x "$bin" ]; then "$bin" 2>/dev/null
  else osascript -e 'clipboard info' 2>/dev/null
  fi
}

capture() {
  local info hash f count seen
  info=$(pb_types)
  [ -z "$info" ] && return

  # pbinfo reports changeCount first. If it has not moved since the last capture
  # there is nothing new to store, and we skip pngpaste/pbpaste and the hashing
  # entirely: that is most of the cost of opening the popup twice in a row.
  count=${info#changeCount:}; count=${count%%$'\n'*}
  if [ -n "$count" ] && [ "$count" != "$info" ]; then
    read -r seen < "$STORE/.changecount" 2>/dev/null
    [ "$seen" = "$count" ] && return
    printf '%s' "$count" > "$STORE/.changecount" 2>/dev/null
  fi
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
