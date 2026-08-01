#!/bin/bash
# Config state machine tests.
#
# These exist because theme and iconset selection silently stopped working: the
# picker wrote to one path while the bar read another, and nothing failed loudly.
# Every test below maps to a real defect that shipped.
#
# Each case runs against a throwaway SKETCHETC_CONFIG, so real config is never
# touched. Run directly, from .githooks/pre-commit, or in CI.
set -uo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"

# A pristine copy of config/, without the legacy in-tree state files a developer
# machine accumulates (.theme, settings.conf, ...). Without this the tests depend
# on whatever happens to be lying around in the working tree, which is how the
# first run of this suite "failed" against perfectly correct code.
FIXTURE=$(mktemp -d)/config
mkdir -p "$FIXTURE"
cp -R "$REPO/config/." "$FIXTURE/"
rm -f "$FIXTURE"/.theme "$FIXTURE"/.iconset "$FIXTURE"/.notify_sound \
      "$FIXTURE"/.extras_collapsed "$FIXTURE"/.fs_guard_off "$FIXTURE"/.update_skip \
      "$FIXTURE"/settings.conf "$FIXTURE"/widgets.conf
rm -rf "$FIXTURE/.cache"
export CONFIG_DIR="$FIXTURE"
PASS=0 FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   %s\n' "$1"; }
bad()  { FAIL=$((FAIL + 1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
is()   { [ "$2" = "$3" ] && ok "$1" || bad "$1" "$2" "$3"; }

sandbox() { SB=$(mktemp -d); mkdir -p "$SB/themes"; }
cleanup() { [ -n "${SB:-}" ] && rm -rf "$SB"; rm -rf "$CONFIG_DIR/.cache"; }
# one trap only: a second EXIT trap silently replaces the first
cleanup_all() { cleanup; rm -rf "$(dirname "$FIXTURE")"; }
trap cleanup_all EXIT

# run a snippet with the sandbox as the user config dir, cache always cold
inbox() { rm -rf "$CONFIG_DIR/.cache"; SKETCHETC_CONFIG="$SB" bash -c "cd '$REPO'; $1" 2>/dev/null; }

echo "state machine"

# --- selection round trips, which is the bug that started this -----------------
sandbox
is "theme selection reaches the bar" "cyberpunk" \
  "$(inbox 'source config/plugins/user_config.sh; uc_ensure; config/plugins/state_cli.sh set theme cyberpunk >/dev/null; source config/colors.sh; printf "%s" "$THEME"')"
is "iconset selection reaches the bar" "emoji" \
  "$(inbox 'source config/plugins/user_config.sh; uc_ensure; config/plugins/state_cli.sh set iconset emoji >/dev/null; source config/colors.sh; printf "%s" "$ICONSET"')"
is "selecting a theme changes the actual colours" "$(grep '^export PINK' "$CONFIG_DIR/themes/cyberpunk.sh" | sed 's/.*=//; s/ .*//')" \
  "$(inbox 'source config/plugins/user_config.sh; uc_ensure; config/plugins/state_cli.sh set theme cyberpunk >/dev/null; source config/colors.sh; printf "%s" "$PINK"')"
cleanup

# --- defaults are declared once, not hardcoded in code ------------------------
sandbox
is "unset theme falls back to the declared default" \
  "$(awk -F= '$1=="theme"{print $2}' "$CONFIG_DIR/settings.default.conf")" \
  "$(inbox 'source config/plugins/user_config.sh; uc_ensure; source config/colors.sh; printf "%s" "$THEME"')"
# if any code carries its own fallback, changing the declaration will not move it
TMPD=$(mktemp -d); cp "$CONFIG_DIR/settings.default.conf" "$TMPD/orig"
sed -i '' 's/^theme=.*/theme=matrix/' "$CONFIG_DIR/settings.default.conf"
sandbox
is "changing the declared default changes behaviour" "matrix" \
  "$(inbox 'source config/plugins/user_config.sh; uc_ensure; source config/colors.sh; printf "%s" "$THEME"')"
cp "$TMPD/orig" "$CONFIG_DIR/settings.default.conf"; rm -rf "$TMPD"
cleanup

# --- a theme the user edited must beat the shipped one of the same name --------
sandbox
sed 's/^export PINK=.*/export PINK=0xUSERWINS/' "$CONFIG_DIR/themes/vice-city.sh" > "$SB/themes/vice-city.sh"
is "user theme wins over the built-in of the same name" "0xUSERWINS" \
  "$(inbox 'source config/plugins/user_config.sh; uc_ensure; config/plugins/state_cli.sh set theme vice-city >/dev/null; source config/colors.sh; printf "%s" "$PINK"')"
cleanup

# --- upgrading must not lose anything the user chose --------------------------
LEGACY=$(mktemp -d)
mkdir -p "$LEGACY/themes"
printf 'data_dir=/Users/someone/MyJournal\nsound=off\n' > "$LEGACY/settings.conf"
printf 'clipboard=on\nnetwork=off\n' > "$LEGACY/widgets.conf"
printf 'cyberpunk\n' > "$LEGACY/.theme"
printf 'emoji\n'     > "$LEGACY/.iconset"
printf 'on\n'        > "$LEGACY/.extras_collapsed"
: > "$LEGACY/.fs_guard_off"
sandbox
UP="source config/plugins/user_config.sh; CONFIG_DIR='$LEGACY' uc_migrate;"
is "upgrade keeps data_dir"        "/Users/someone/MyJournal" "$(inbox "$UP printf '%s' \"\$(state_get data_dir)\"")"
is "upgrade keeps a changed sound" "off"       "$(inbox "$UP printf '%s' \"\$(state_get sound)\"")"
is "upgrade keeps the theme"       "cyberpunk" "$(inbox "$UP printf '%s' \"\$(state_get theme)\"")"
is "upgrade keeps the iconset"     "emoji"     "$(inbox "$UP printf '%s' \"\$(state_get iconset)\"")"
is "upgrade keeps the tray state"  "on"        "$(inbox "$UP printf '%s' \"\$(state_get extras_collapsed)\"")"
is "upgrade keeps a guard opt-out" "off"       "$(inbox "$UP printf '%s' \"\$(state_get fs_guard)\"")"
is "upgrade keeps widget toggles"  "off"       "$(inbox "$UP source config/colors.sh; widget_on network && printf on || printf off")"

# running it twice must change nothing
BEFORE=$(inbox "$UP find \"\$SKETCHETC_CONFIG\" -type f -exec shasum {} + | sort")
AFTER=$(inbox "$UP $UP find \"\$SKETCHETC_CONFIG\" -type f -exec shasum {} + | sort")
is "migration is idempotent" "same" "$([ "$BEFORE" = "$AFTER" ] && echo same || echo changed)"
rm -rf "$LEGACY"; cleanup

# --- new keys and widgets must reach existing users ---------------------------
sandbox
printf 'data_dir=/tmp/x\n' > "$SB/settings.conf"
printf 'clipboard=on\n'    > "$SB/widgets.conf"
is "a key only in the default still resolves" \
  "$(awk -F= '$1=="clip_max"{print $2}' "$CONFIG_DIR/settings.default.conf")" \
  "$(inbox 'source config/plugins/user_config.sh; printf "%s" "$(state_get clip_max)"')"
is "a widget added in a release appears" "on" \
  "$(inbox 'source config/colors.sh; widget_on shelf && printf on || printf off')"
cleanup

# --- nothing may hardcode where config lives ----------------------------------
echo "guards"
HITS=$(grep -rn --include='*.sh' --include='*.swift' \
        -E '\.config/sketchybar/\.(theme|iconset|notify_sound|extras_collapsed|fs_guard|update_skip|last_seen_version)|\.config/sketchybar/(settings|widgets)\.conf' \
        "$REPO/config" "$REPO/scripts" 2>/dev/null | grep -vE '^\s*[^:]+:[0-9]+:\s*(//|#)' | grep -v 'user_config.sh')
is "no code hardcodes a user config path" "" "$HITS"

# state written into the checkout is lost on reinstall and can block a pull
WRITES=$(grep -rn --include='*.sh' -E '>\s*"?\$\{?CONFIG_DIR\}?/\.[a-z_]+|touch "\$CONFIG_DIR/\.[a-z_]+' \
        "$REPO/config" 2>/dev/null | grep -v '\.cache' | grep -vE ':\s*(//|#)')
is "no state is written into the checkout" "" "$WRITES"

echo
printf '%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
