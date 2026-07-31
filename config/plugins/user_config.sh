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

# One-shot migration. Runs before anything reads a setting, and only when the
# user directory does not exist yet, so it can never run twice or overwrite a
# newer value with an older one.
uc_migrate() {
  [ -d "$USER_CONF_DIR" ] && return 0
  mkdir -p "$USER_CONF_DIR/themes" 2>/dev/null || return 0

  local cfg="${CONFIG_DIR:-$HOME/.config/sketchybar}"
  # an existing install has its values in the checkout: carry them over verbatim
  if [ -f "$cfg/settings.conf" ]; then cp "$cfg/settings.conf" "$USER_SETTINGS" 2>/dev/null
  elif [ -f "$(uc_defaults settings)" ]; then cp "$(uc_defaults settings)" "$USER_SETTINGS" 2>/dev/null; fi
  if [ -f "$cfg/widgets.conf" ]; then cp "$cfg/widgets.conf" "$USER_WIDGETS" 2>/dev/null
  elif [ -f "$(uc_defaults widgets)" ]; then cp "$(uc_defaults widgets)" "$USER_WIDGETS" 2>/dev/null; fi

  # single-value state files and any themes the user made
  local f
  for f in .theme .iconset .notify_sound .extras_collapsed; do
    [ -f "$cfg/$f" ] && cp "$cfg/$f" "$USER_CONF_DIR/$f" 2>/dev/null
  done
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
