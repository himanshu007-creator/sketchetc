#!/bin/bash
# notify.sh <category> <title> <message>
#
# Every category is independently `on` (banner and sound), `silent` (banner, no
# sound) or `off` (nothing), read from notify_<category>. Sound used to be one
# global switch, so quieting a single chatty notification meant silencing every
# notification in the app.
#
# `sound=off` remains the master switch over all of them. An unknown or blank
# category always notifies: a caller that forgets to declare one should be noisy
# and get noticed, not disappear.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/plugins/user_config.sh"
uc_ensure

CAT="$1" TITLE="$2" MSG="$3"
# back-compat: two-arg calls are (title, message) with no category
if [ -z "$MSG" ]; then TITLE="$1"; MSG="$2"; CAT=""; fi

# AppleScript string literals are double quoted, so a quote or a backslash
# anywhere in a message was a syntax error and the notification simply never
# appeared. Saving a prompt whose text contains quotes hit this immediately.
esc() { local s=${1//\\/\\\\}; printf '%s' "${s//\"/\\\"}"; }
TITLE=$(esc "$TITLE")
MSG=$(esc "$MSG")

WANT_SOUND=1
if [ -n "$CAT" ]; then
  case "$(state_get "notify_$CAT")" in
    off)    exit 0 ;;
    silent) WANT_SOUND=0 ;;
  esac
fi

# the global switch still wins over any category that asked for sound
[ "$(state_get sound)" = "off" ] && WANT_SOUND=0

if [ "$WANT_SOUND" = 0 ]; then
  osascript -e "display notification \"$MSG\" with title \"$TITLE\""
  exit 0
fi

CUSTOM=$(state_get sound_file)
if [ -n "$CUSTOM" ] && [ -f "$CUSTOM" ]; then
  osascript -e "display notification \"$MSG\" with title \"$TITLE\""
  afplay "$CUSTOM" >/dev/null 2>&1 &
else
  osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Glass\""
fi
