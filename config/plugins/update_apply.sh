#!/bin/bash
# Pull the release branch, rebuild helpers, reload, then show what shipped.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
export CONFIG_DIR
source "$CONFIG_DIR/plugins/settings_lib.sh"

APP=$(dirname "$(readlink "$HOME/.config/sketchybar" 2>/dev/null || echo "$CONFIG_DIR")")
CHANNEL=$(setting channel); CHANNEL=${CHANNEL:-production}

OLD=$(cat "$APP/VERSION" 2>/dev/null || echo "0.0.0")

# settings.conf, widgets.conf and any theme the user edited are tracked files, so
# a --ff-only pull refuses to run the moment somebody changes a setting. Set
# their edits aside, pull, then put them back.
STASHED=0
if [ -n "$(git -C "$APP" status --porcelain 2>/dev/null)" ]; then
  git -C "$APP" stash push --quiet --include-untracked -m "sketchetc local settings" 2>/dev/null && STASHED=1
fi

if ! git -C "$APP" pull --ff-only --quiet origin "$CHANNEL" 2>/dev/null; then
  [ "$STASHED" = 1 ] && git -C "$APP" stash pop --quiet 2>/dev/null
  "$CONFIG_DIR/plugins/notify.sh" update "Update failed" "Could not fast-forward. Run: git -C $APP status"
  exit 1
fi

if [ "$STASHED" = 1 ] && ! git -C "$APP" stash pop --quiet 2>/dev/null; then
  # a real conflict: the new version changed the same lines. Keep the update and
  # leave their edits recoverable rather than throwing either side away.
  "$CONFIG_DIR/plugins/notify.sh" update "Settings kept in git stash" \
    "Your edits clashed with this release. Recover with: git -C $APP stash pop"
fi

# helpers are gitignored binaries, so rebuild whatever changed
CONFIG_DIR="$APP/config" "$APP/config/plugins/build.sh"

NEW=$(cat "$APP/VERSION" 2>/dev/null || echo "$OLD")
rm -f "$CONFIG_DIR"/.update_notified_* "$CONFIG_DIR/.update_skip"
sketchybar --reload
sleep 2
"$CONFIG_DIR/plugins/notify.sh" update "sketchetc updated" "Now on v$NEW"
echo "$NEW" > "$CONFIG_DIR/.last_seen_version"
"$CONFIG_DIR/plugins/release_open.sh" "$OLD" &
