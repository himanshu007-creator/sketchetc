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
PASS=0 FAIL=0 SKIP=0

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

# --- notifications: three states, independently per category ------------------
# Sound used to be one global switch, so quieting a chatty notification meant
# silencing every notification in the app.
sandbox
STUB=$(mktemp -d)
printf '#!/bin/bash\necho "$*" >> "$STUB_LOG"\n' > "$STUB/osascript"
printf '#!/bin/bash\necho "afplay $*" >> "$STUB_LOG"\n' > "$STUB/afplay"
chmod +x "$STUB/osascript" "$STUB/afplay"

notify_as() { # <category> <state> -> what notify.sh actually did
  local cat="$1" want="$2"
  inbox "source config/plugins/user_config.sh; uc_ensure; state_set notify_$cat '$want'" >/dev/null
  export STUB_LOG=$(mktemp)
  rm -rf "$CONFIG_DIR/.cache"
  SKETCHETC_CONFIG="$SB" STUB_LOG="$STUB_LOG" PATH="$STUB:$PATH" \
    bash "$REPO/config/plugins/notify.sh" "$cat" T M 2>/dev/null
  if [ ! -s "$STUB_LOG" ]; then echo "nothing"
  elif grep -q 'sound name' "$STUB_LOG"; then echo "sound"
  else echo "banner"; fi
}
is "notify on gives a banner with sound" "sound"   "$(notify_as agents on)"
is "notify silent gives a banner only"   "banner"  "$(notify_as agents silent)"
is "notify off gives nothing"            "nothing" "$(notify_as agents off)"

# the bug this replaced: agent notifications shared the generic toggles bucket
inbox 'source config/plugins/user_config.sh; uc_ensure; state_set notify_agents off' >/dev/null
export STUB_LOG=$(mktemp)
SKETCHETC_CONFIG="$SB" STUB_LOG="$STUB_LOG" PATH="$STUB:$PATH" \
  bash "$REPO/config/plugins/notify.sh" toggles T M 2>/dev/null
is "silencing one category leaves the others alone" "fires" \
  "$([ -s "$STUB_LOG" ] && echo fires || echo silent)"
is "no agent notification still uses the shared bucket" "0" \
  "$(grep -c 'notify.sh"* toggles' "$REPO/config/plugins/ai_agents.sh")"
rm -rf "$STUB"; cleanup

# --- the custom sound key was shaped like a category and is not one ------------
LEG=$(mktemp -d); sandbox
printf 'notify_sound=/System/Library/Sounds/Ping.aiff\n' > "$LEG/settings.conf"
is "a custom sound survives the key rename" "/System/Library/Sounds/Ping.aiff" \
  "$(inbox "source config/plugins/user_config.sh; CONFIG_DIR='$LEG' uc_migrate; printf '%s' \"\$(state_get sound_file)\"")"
rm -rf "$LEG"; cleanup

# --- nothing may hardcode where config lives ----------------------------------
echo "guards"
HITS=$(grep -rn --include='*.sh' --include='*.swift' \
        -E '\.config/sketchybar/\.(theme|iconset|notify_sound|extras_collapsed|fs_guard|update_skip|last_seen_version)|\.config/sketchybar/(settings|widgets)\.conf' \
        "$REPO/config" "$REPO/scripts" 2>/dev/null | grep -vE '^\s*[^:]+:[0-9]+:\s*(//|#)' | grep -v 'user_config.sh')
is "no code hardcodes a user config path" "" "$HITS"

# The theme studio's palette came out swapped because two arguments were added
# and every later position shifted. A GUI cannot be asserted headlessly, but the
# actual defect was a contract mismatch between caller and binary, and that is
# checkable: the flags one passes must be exactly the flags the other reads.
PASSED_FLAGS=$(grep -oE '\-\-[a-z0-9-]+' "$REPO/config/plugins/theme_open.sh" | sort -u)
PARSED_FLAGS=$(grep -oE 'need\("[a-z0-9-]+"\)' "$REPO/config/plugins/bin/theme_win.swift" \
               | sed 's/need("/--/; s/")//' | sort -u)
is "theme_win reads exactly the flags theme_open passes" "" \
  "$(comm -3 <(printf '%s\n' "$PASSED_FLAGS") <(printf '%s\n' "$PARSED_FLAGS") | tr -d '\t')"

# a missing flag has to stop the program, not render the wrong colour silently
# Binaries are gitignored, so CI has none. Compile it rather than skip: a test
# that silently disappears on the machine that gates merges is barely a test.
TW="$REPO/config/plugins/bin/theme_win"
if [ ! -x "$TW" ] && command -v swiftc >/dev/null 2>&1; then
  TW=$(mktemp -d)/theme_win
  swiftc -O -o "$TW" "$REPO/config/plugins/bin/theme_win.swift" 2>/dev/null || TW=""
fi
if [ -n "$TW" ] && [ -x "$TW" ]; then
  "$TW" --builtin-dir /tmp --user-dir /tmp >/dev/null 2>&1
  is "a missing flag exits non-zero" "2" "$?"
else
  SKIP=$((SKIP + 1)); printf '  SKIP a missing flag exits non-zero (no swiftc)\n'
fi

# state written into the checkout is lost on reinstall and can block a pull
WRITES=$(grep -rn --include='*.sh' -E '>\s*"?\$\{?CONFIG_DIR\}?/\.[a-z_]+|touch "\$CONFIG_DIR/\.[a-z_]+' \
        "$REPO/config" 2>/dev/null | grep -v '\.cache' | grep -vE ':\s*(//|#)')
is "no state is written into the checkout" "" "$WRITES"

# colors.sh legitimately writes its env cache under config/.cache, which is why
# the grep above skips it. The danger is the generated file getting COMMITTED:
# `git add -A` picked two up, they shipped in the release tarball carrying one
# machine's widget list and palette, and shellcheck failed on generated syntax.
is "generated caches stay untracked" "" "$(git -C "$REPO" ls-files config/.cache 2>/dev/null)"

# config/settings.conf is tracked as a migration source, so whatever sits in it
# ships to everyone. It carried data_dir=/Users/<me>/... , which uc_migrate
# copies verbatim on any install that does not go through docs/install.sh: the
# tarball and clone-then-./install.sh routes both handed new users a home
# directory they cannot even create. Empty resolves per machine.
HOMEPATHS=$(git -C "$REPO" grep -nI '/Users/[a-z]' -- 'config/*.conf' 2>/dev/null)
is "no tracked config hardcodes a home directory" "" "$HOMEPATHS"

# The update confirmation used to return osascript's exit status, and with no
# button named "Cancel" AppleScript raised nothing on dismissal: both buttons
# exited 0, so "Not now" installed the update. A gate that cannot say no is
# worse than no gate, so every way out of the dialog is checked here. ask() is
# lifted from the source rather than restated, or the test drifts from the code.
ASKDIR=$(mktemp -d)
sed -n '/^ask() {/,/^}/p' "$REPO/config/plugins/update_now.sh" > "$ASKDIR/ask.sh"
ask_says() { # <stubbed osascript body> -> yes|no
  printf '#!/bin/bash\n%s\n' "$1" > "$ASKDIR/osascript"; chmod +x "$ASKDIR/osascript"
  PATH="$ASKDIR:$PATH" bash -c "source '$ASKDIR/ask.sh'; ask t b Update" && echo yes || echo no
}
is "confirming the update installs it"      "yes" "$(ask_says 'echo "button returned:Update"')"
is "Not now does not install the update"    "no"  "$(ask_says 'echo "button returned:Not now"')"
is "dismissing does not install the update" "no"  "$(ask_says 'exit 1')"
is "an unreadable dialog never means yes"   "no"  "$(ask_says 'echo garbage')"
rm -rf "$ASKDIR"

echo
printf '%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
