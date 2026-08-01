#!/bin/bash
# notify.sh <category> <title> <message>
# Categories are gated by settings.conf (notify_<category>=on|off); `sound=off`
# silences the chime. Unknown/blank category always notifies.
source "$CONFIG_DIR/plugins/user_config.sh"
uc_ensure
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
SETTINGS="$(uc_path settings)"

setting() { awk -F= -v k="$1" '$1 == k {print $2; exit}' "$SETTINGS" 2>/dev/null; }

CAT="$1" TITLE="$2" MSG="$3"
# back-compat: two-arg calls are (title, message) with no category
if [ -z "$MSG" ]; then TITLE="$1"; MSG="$2"; CAT=""; fi

# AppleScript string literals are double quoted, so a quote or a backslash
# anywhere in a message was a syntax error and the notification simply never
# appeared. Saving a prompt whose text contains quotes hit this immediately.
esc() { local s=${1//\\/\\\\}; printf '%s' "${s//\"/\\\"}"; }
TITLE=$(esc "$TITLE")
MSG=$(esc "$MSG")

if [ -n "$CAT" ]; then
  V=$(setting "notify_$CAT")
  [ "$V" = "off" ] && exit 0
fi

if [ "$(setting sound)" = "off" ]; then
  osascript -e "display notification \"$MSG\" with title \"$TITLE\""
  exit 0
fi

CUSTOM=$(state_get notify_sound)
if [ -n "$CUSTOM" ] && [ -f "$CUSTOM" ]; then
  osascript -e "display notification \"$MSG\" with title \"$TITLE\""
  afplay "$CUSTOM" >/dev/null 2>&1 &
else
  osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Glass\""
fi
