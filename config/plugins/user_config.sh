#!/bin/bash
# Where the user's own settings live: ~/.config/sketchetc, never inside the repo.
#
# settings.conf and widgets.conf used to be tracked files in the checkout, which
# meant every checkout carried its own copy. Switching which checkout ran the bar
# silently switched data_dir, and the journal appeared to vanish because the bar
# was reading a different folder. The same trap catches anyone who re-clones,
# installs on a second machine, or resolves a merge against the repo's copy.
#
# Config the user owns therefore lives outside any directory git manages. The
# repo ships *.default.conf; the user's file wins key by key, so a new setting in
# a later release appears without touching anything already set.
USER_CONF_DIR="${SKETCHETC_CONFIG:-$HOME/.config/sketchetc}"
USER_SETTINGS="$USER_CONF_DIR/settings.conf"
USER_WIDGETS="$USER_CONF_DIR/widgets.conf"

uc_defaults() { # <settings|widgets> -> path of the shipped default
  echo "${CONFIG_DIR:-$HOME/.config/sketchybar}/$1.default.conf"
}

# ---------------------------------------------------------------------------
# The state machine.
#
# Every preference is a key in the user's settings.conf, and these three
# functions are the ONLY way to touch one. No caller builds a path, so a reader
# and a writer can no longer disagree about where a value lives, which is exactly
# how theme selection broke: the picker wrote to ~/.config/sketchybar/.theme
# while colors.sh read ~/.config/sketchetc/.theme, and nothing looked wrong until
# you tried to change a theme.
#
# Defaults are declared once, in settings.default.conf. Code carrying its own
# fallback is how two places ended up independently deciding "vice-city".

state_raw() { # <key> -> the user's value only, empty if unset. For "is it set?"
  [ -f "$USER_SETTINGS" ] || return 0
  awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$USER_SETTINGS" 2>/dev/null
}

state_get() { # <key> [fallback] -> user value, else shipped default, else fallback
  local v
  v=$(state_raw "$1")
  if [ -z "$v" ]; then
    v=$(awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' \
          "$(uc_defaults settings)" 2>/dev/null)
  fi
  [ -z "$v" ] && v="${2:-}"
  printf '%s' "$v"
}

state_set() { # <key> <value> — atomic, so a crash mid-write cannot truncate config
  local key="$1" val="$2" tmp
  mkdir -p "$USER_CONF_DIR" 2>/dev/null || return 1
  [ -f "$USER_SETTINGS" ] || : > "$USER_SETTINGS"
  tmp="$USER_SETTINGS.$$"
  awk -F= -v k="$key" -v v="$val" '
    $1 == k { if (!done) { print k "=" v; done = 1 } ; next }
    { print }
    END { if (!done) print k "=" v }
  ' "$USER_SETTINGS" > "$tmp" 2>/dev/null && mv "$tmp" "$USER_SETTINGS" || rm -f "$tmp"
}

state_clear() { # <key>
  local tmp="$USER_SETTINGS.$$"
  [ -f "$USER_SETTINGS" ] || return 0
  awk -F= -v k="$1" '$1 != k' "$USER_SETTINGS" > "$tmp" 2>/dev/null \
    && mv "$tmp" "$USER_SETTINGS" || rm -f "$tmp"
}

# Ephemeral state: caches, one-time nudges, update bookkeeping. Losing any of it
# costs nothing, but it must not sit in the checkout where a release can collide
# with it.
uc_runtime() { # <name> -> path under the user's state dir
  mkdir -p "$USER_CONF_DIR/state" 2>/dev/null
  echo "$USER_CONF_DIR/state/$1"
}

# One-shot migration. Runs before anything reads a setting, and only when the
# user directory does not exist yet, so it can never run twice or overwrite a
# newer value with an older one.
#
# The in-tree settings.conf/widgets.conf deliberately stay tracked and untouched
# by releases. Deleting them upstream would have made `git pull --ff-only` refuse
# for every existing user, because everyone has a locally modified copy, and the
# update path would have stashed their settings somewhere this migration cannot
# see them: data_dir would come back empty and the journal would look lost. They
# are legacy migration sources now, read once and never written again.
#
# Per file, not all or nothing. Returning early when the directory merely exists
# meant a partial or interrupted migration never completed: on this machine
# .iconset was never copied at all and .theme stayed stale, so the theme picker
# wrote somewhere nothing read. Anything missing is filled in; anything present
# is left alone, which keeps it idempotent.
uc_migrate() {
  mkdir -p "$USER_CONF_DIR/themes" "$USER_CONF_DIR/state" 2>/dev/null || return 0

  local cfg="${CONFIG_DIR:-$HOME/.config/sketchybar}"

  # A v1.3.1 install could have stashed the user's settings during its update.
  # Recover from there before falling back to defaults, so nobody who upgraded
  # through that window silently loses their data folder.
  local app stash_file
  app=$(dirname "$(readlink "$HOME/.config/sketchybar" 2>/dev/null || echo "$cfg")")
  if [ ! -f "$USER_SETTINGS" ] && [ ! -f "$cfg/settings.conf" ] && git -C "$app" rev-parse --git-dir >/dev/null 2>&1; then
    stash_file=$(git -C "$app" stash list --format='%gd' 2>/dev/null | head -1)
    if [ -n "$stash_file" ]; then
      git -C "$app" show "$stash_file:config/settings.conf" > "$USER_SETTINGS" 2>/dev/null || rm -f "$USER_SETTINGS"
      git -C "$app" show "$stash_file:config/widgets.conf"  > "$USER_WIDGETS"  2>/dev/null || rm -f "$USER_WIDGETS"
      [ -s "$USER_SETTINGS" ] && return 0
    fi
  fi

  # an existing install has its values in the checkout: carry them over verbatim
  if [ ! -f "$USER_SETTINGS" ]; then
    if [ -f "$cfg/settings.conf" ]; then cp "$cfg/settings.conf" "$USER_SETTINGS" 2>/dev/null
    elif [ -f "$(uc_defaults settings)" ]; then cp "$(uc_defaults settings)" "$USER_SETTINGS" 2>/dev/null; fi
  fi
  if [ ! -f "$USER_WIDGETS" ]; then
    if [ -f "$cfg/widgets.conf" ]; then cp "$cfg/widgets.conf" "$USER_WIDGETS" 2>/dev/null
    elif [ -f "$(uc_defaults widgets)" ]; then cp "$(uc_defaults widgets)" "$USER_WIDGETS" 2>/dev/null; fi
  fi

  # Legacy dotfiles become settings keys. They were separate files scattered
  # across the checkout, each with its own reader and writer, which is precisely
  # how .theme ended up split brained. Read once, then never again.
  local f key val
  for f in .theme .iconset .notify_sound .extras_collapsed; do
    key="${f#.}"
    [ -n "$(state_raw "$key")" ] && continue          # already a key: leave it
    for src in "$USER_CONF_DIR/$f" "$cfg/$f"; do
      [ -f "$src" ] || continue
      read -r val < "$src" 2>/dev/null
      [ -n "$val" ] && { state_set "$key" "$val"; break; }
    done
  done
  # preferences that used to be marker files
  [ -f "$cfg/.fs_guard_off" ] && [ -z "$(state_raw fs_guard)" ] && state_set fs_guard off
  if [ -f "$cfg/.update_skip" ] && [ -z "$(state_raw update_skip)" ]; then
    read -r val < "$cfg/.update_skip" 2>/dev/null
    [ -n "$val" ] && state_set update_skip "$val"
  fi
  for f in "$cfg"/themes/*.sh; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      vice-city.sh|cyberpunk.sh|matrix.sh|catppuccin.sh|miami-sunset.sh) continue ;;  # built in
    esac
    cp "$f" "$USER_CONF_DIR/themes/" 2>/dev/null
  done
}

# Ensure the files exist, seeding from the shipped defaults on a fresh install.
uc_ensure() {
  uc_migrate
  mkdir -p "$USER_CONF_DIR/themes" 2>/dev/null
  [ -f "$USER_SETTINGS" ] || cp "$(uc_defaults settings)" "$USER_SETTINGS" 2>/dev/null
  [ -f "$USER_WIDGETS" ]  || cp "$(uc_defaults widgets)"  "$USER_WIDGETS"  2>/dev/null
}

# Path a caller should read for a given kind, preferring the user's own file.
uc_path() { # <settings|widgets>
  case "$1" in
    settings) [ -f "$USER_SETTINGS" ] && echo "$USER_SETTINGS" || uc_defaults settings ;;
    widgets)  [ -f "$USER_WIDGETS" ]  && echo "$USER_WIDGETS"  || uc_defaults widgets ;;
  esac
}

# Single-value state (.theme, .iconset, ...) also lives in the user directory
uc_state() { echo "$USER_CONF_DIR/$1"; }
