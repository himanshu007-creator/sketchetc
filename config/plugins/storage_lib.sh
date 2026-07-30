#!/bin/bash
# One folder holds every piece of user data. Set it once (Settings → Data folder
# or the journal menu) and journal entries, aura history and clipboard history
# all live under it, so a reinstall only has to point at the same folder again.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/plugins/settings_lib.sh"

DEFAULT_DATA="$HOME/.local/share/sketchetc/data"

data_dir() {
  local d
  d=$(setting data_dir)
  # compat: older installs kept a journal-only root in journal.conf
  if [ -z "$d" ]; then
    d=$(awk -F= '$1=="root"{print $2; exit}' "$HOME/.local/share/sketchetc/journal.conf" 2>/dev/null)
    [ -n "$d" ] && d="$d"
  fi
  echo "${d:-$DEFAULT_DATA}"
}
journal_root() { echo "$(data_dir)/journal"; }
aura_dir()     { echo "$(data_dir)/aura"; }
clip_dir()     { echo "$(data_dir)/clipboard"; }

data_ready() { # false when the folder vanished (external disk, deleted)
  local d; d=$(data_dir)
  [ -d "$d" ] && [ -w "$d" ]
}

is_journal_root() { # <dir> — a journal root itself, not a data folder wrapping one
  [ -f "$1/index.log" ] && return 0
  [ -d "$1/personal" ] && return 0
  compgen -G "$1/2[0-9][0-9][0-9]" >/dev/null 2>&1   # dated YYYY folders
}

data_adopt_bare_journal() { # <data dir>
  # Somebody pointing at their existing journal folder means "use my history",
  # not "start empty inside it". Entries live in journal/, so slide a bare
  # journal root down one level instead of silently shadowing it.
  local d="$1"
  [ -d "$d" ] || return 0
  is_journal_root "$d" || return 0
  [ -f "$d/journal/index.log" ] && return 0   # already migrated

  mkdir -p "$d/journal" 2>/dev/null || return 0
  # locked entries are chflagged uchg, which blocks the move; unlock, move, relock
  find "$d" -maxdepth 3 -name '*.md' -flags +uchg -exec chflags nouchg {} \; 2>/dev/null
  local item
  for item in "$d"/2[0-9][0-9][0-9] "$d/personal" "$d/index.log"; do
    [ -e "$item" ] || continue
    mv "$item" "$d/journal/" 2>/dev/null
  done
  find "$d/journal" -name '*.md' -path '*/journal/2*' -exec chflags uchg {} \; 2>/dev/null
}

data_ensure() {
  local d; d=$(data_dir)
  data_adopt_bare_journal "$d"
  mkdir -p "$d/journal" "$d/aura" "$d/clipboard" 2>/dev/null
}

data_has_content() { # <dir> — does this look like a sketchetc data folder?
  [ -d "$1/journal" ] || [ -d "$1/aura" ] || [ -d "$1/clipboard" ] || is_journal_root "$1"
}
