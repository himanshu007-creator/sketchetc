#!/bin/bash
# Manual "check for updates", and the confirmation gate the update pill uses too.
# Nothing here installs anything until the user says yes.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
export CONFIG_DIR
source "$CONFIG_DIR/plugins/settings_lib.sh"

APP=$(dirname "$(readlink "$HOME/.config/sketchybar" 2>/dev/null || echo "$CONFIG_DIR")")
CHANNEL=$(setting channel); CHANNEL=${CHANNEL:-production}
QUIET="${1:-}"   # "quiet" skips the up-to-date dialog, used by the pill

ask() {  # ask <title> <body> <ok-button>
  osascript -e "display dialog \"$2\" with title \"$1\" \
    buttons {\"Not now\", \"$3\"} default button \"$3\" with icon note" >/dev/null 2>&1
}
tell() {
  osascript -e "display dialog \"$2\" with title \"$1\" buttons {\"OK\"} default button \"OK\" with icon note" >/dev/null 2>&1
}

if ! git -C "$APP" rev-parse --git-dir >/dev/null 2>&1; then
  [ "$QUIET" = quiet ] || tell "sketchetc" "This copy was not installed with git, so it cannot check for updates. Reinstall with the one line installer to get updates."
  exit 0
fi

if ! git -C "$APP" fetch --quiet origin "$CHANNEL" 2>/dev/null; then
  [ "$QUIET" = quiet ] || tell "sketchetc" "Could not reach GitHub. Check your connection and try again."
  exit 0
fi

BEHIND=$(git -C "$APP" rev-list --count "HEAD..origin/$CHANNEL" 2>/dev/null || echo 0)
HERE=$(cat "$APP/VERSION" 2>/dev/null || echo "?")
THERE=$(git -C "$APP" show "origin/$CHANNEL:VERSION" 2>/dev/null || echo "?")

if [ "${BEHIND:-0}" -eq 0 ]; then
  # a manual check should always answer, even when the answer is "nothing to do"
  [ "$QUIET" = quiet ] || tell "sketchetc is up to date" "You are on v$HERE, the latest on the $CHANNEL channel."
  sketchybar --set updater drawing=off 2>/dev/null
  exit 0
fi

# summarise what is actually coming, so "yes" is an informed yes
# a release lands as a commit on develop and again as production's merge commit,
# so the same subject shows up twice without the dedupe
SUMMARY=$(git -C "$APP" log --pretty='- %s' "HEAD..origin/$CHANNEL" 2>/dev/null \
  | grep -v '^- Merge' | awk '!seen[$0]++' | head -6 \
  | sed 's/"/\\"/g' | tr '\n' '@' | sed 's/@/\\n/g')

if ask "Update sketchetc?" "v$HERE  ->  v$THERE ($BEHIND commit(s))\\n\\n$SUMMARY\\n\\nThe bar reloads when it finishes." "Update"; then
  "$CONFIG_DIR/plugins/notify.sh" update "sketchetc" "Updating to v$THERE"
  exec "$CONFIG_DIR/plugins/update_apply.sh"
fi
exit 0
