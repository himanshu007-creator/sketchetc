#!/bin/bash
# sketchetc installer · curl -fsSL https://himanshu007-creator.github.io/sketchetc/install.sh | bash
# Idempotent: first run installs, later runs upgrade in place.
set -euo pipefail

REPO_URL="https://github.com/himanshu007-creator/sketchetc.git"
BRANCH="${SKETCHETC_CHANNEL:-production}"
APP="$HOME/.local/share/sketchetc/app"
DRY=0
COUNT=1
LOCAL=0
for a in "$@"; do
  [ "$a" = "--dry-run" ] && DRY=1
  [ "$a" = "--no-count" ] && COUNT=0
  [ "$a" = "--local" ] && LOCAL=1
done
[ -n "${SKETCHETC_NO_TELEMETRY:-}" ] && COUNT=0

# --local installs from the checkout this script sits in rather than cloning, so
# the repo's own install.sh can be a one line wrapper around this file. Two
# installers drifting apart is what let the same bug ship twice.
if [ "$LOCAL" = 1 ]; then
  APP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  [ -d "$APP/config" ] || { echo "--local: no config/ next to $APP, is this a sketchetc checkout?"; exit 1; }
fi

say()  { printf '\033[38;5;213m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[38;5;215m  ! \033[0m%s\n' "$1"; }
run()  { if [ "$DRY" = 1 ]; then printf '   would run: %s\n' "$*"; else "$@"; fi }

[ "$(uname)" = "Darwin" ] || { echo "sketchetc is macOS only."; exit 1; }

# ---------- dependencies ----------
if ! command -v brew >/dev/null; then
  say "Homebrew is required: https://brew.sh"
  exit 1
fi
say "Installing dependencies"
run brew tap FelixKratz/formulae
run brew tap koekeishiya/formulae
brew trust felixkratz/formulae   2>/dev/null || true
brew trust koekeishiya/formulae  2>/dev/null || true
for f in sketchybar macmon pngpaste switchaudio-osx blueutil cliclick; do
  if brew list "$f" &>/dev/null; then printf '   have %s\n' "$f"; else run brew install "$f"; fi
done
brew list skhd &>/dev/null || run brew install koekeishiya/formulae/skhd
brew list --cask font-jetbrains-mono-nerd-font &>/dev/null || run brew install --cask font-jetbrains-mono-nerd-font
if [ ! -f "$HOME/Library/Fonts/sketchybar-app-font.ttf" ]; then
  # a fresh macOS account has no ~/Library/Fonts yet, and curl will not create
  # it. Under set -e that aborted the whole install before the bar ever started.
  run mkdir -p "$HOME/Library/Fonts"
  run curl -fsSL "https://github.com/kvndrsslr/sketchybar-app-font/releases/latest/download/sketchybar-app-font.ttf" \
    -o "$HOME/Library/Fonts/sketchybar-app-font.ttf" \
    || warn "app icon font download failed, app icons will fall back"
fi

# ---------- code ----------
if [ "$LOCAL" = 1 ]; then
  say "Using this checkout ($APP)"
elif [ -d "$APP/.git" ]; then
  say "Updating sketchetc ($BRANCH)"
  run git -C "$APP" fetch --quiet origin "$BRANCH"
  run git -C "$APP" checkout --quiet "$BRANCH"
  run git -C "$APP" pull --ff-only --quiet origin "$BRANCH"
else
  say "Fetching sketchetc ($BRANCH)"
  run mkdir -p "$(dirname "$APP")"
  run git clone --quiet --branch "$BRANCH" "$REPO_URL" "$APP"
fi

# ---------- link config ----------
say "Linking config into ~/.config/sketchybar"
if [ -e "$HOME/.config/sketchybar" ] && [ ! -L "$HOME/.config/sketchybar" ]; then
  BK="$HOME/.config/sketchybar.bak.$(date +%s)"
  warn "existing config moved to $BK"
  run mv "$HOME/.config/sketchybar" "$BK"
fi
run mkdir -p "$HOME/.config"
run ln -sfn "$APP/config" "$HOME/.config/sketchybar"
[ "$DRY" = 1 ] || chmod +x "$APP/config/sketchybarrc" "$APP/config"/*.sh "$APP/config/items/"* "$APP/config/plugins/"*.sh 2>/dev/null || true

# ---------- helpers ----------
if command -v swiftc >/dev/null; then
  say "Compiling helpers"
  run env CONFIG_DIR="$APP/config" "$APP/config/plugins/build.sh"
else
  warn "swiftc missing (install Xcode command line tools) — windows and pickers will be unavailable"
fi

# ---------- macOS bits ----------
say "System setup"
run defaults write NSGlobalDomain _HIHideMenuBar -bool false
if [ "$DRY" = 0 ]; then
  hotkeys() {
  TMP=$(mktemp -d); defaults export com.apple.symbolichotkeys "$TMP/shk.plist"
  python3 - "$TMP/shk.plist" <<'PY'
import plistlib, sys
p = sys.argv[1]
with open(p, 'rb') as f: d = plistlib.load(f)
hk = d.setdefault('AppleSymbolicHotKeys', {})
for i, key in enumerate([118, 119, 120, 121]):   # Switch to Desktop 1-4
    hk[str(key)] = {'enabled': True, 'value': {'parameters': [65535, 18 + i, 262144], 'type': 'standard'}}
with open(p, 'wb') as f: plistlib.dump(d, f)
PY
  defaults import com.apple.symbolichotkeys "$TMP/shk.plist"
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  killall Finder 2>/dev/null || true
  }
  hotkeys || warn "could not set the ctrl+1..4 desktop hotkeys, everything else is fine"
fi

if [ "$DRY" = 0 ]; then
mkdir -p "$HOME/.config/skhd" 2>/dev/null || true
grep -q clipboard_choose "$HOME/.config/skhd/skhdrc" 2>/dev/null || \
  echo 'alt - v : CONFIG_DIR=$HOME/.config/sketchybar $HOME/.config/sketchybar/plugins/clipboard_choose.sh' >> "$HOME/.config/skhd/skhdrc"
fi
# both are already-done-is-fine: skhd exits non-zero when the service file
# exists, which under set -e used to abort every reinstall part way through
run skhd --install-service || true
run skhd --restart-service 2>/dev/null || run skhd --start-service || true

say "Starting sketchetc"
run brew services restart sketchybar

# anonymous install counter: one hit on a public tally, nothing about you is
# sent (no IP logging on our side, no id, no phone home afterwards).
# Skip with --no-count or SKETCHETC_NO_TELEMETRY=1
if [ "$COUNT" = 1 ] && [ "$DRY" = 0 ]; then
  curl -s --max-time 3 "https://api.counterapi.dev/v1/sketchetc/installs/up" >/dev/null 2>&1 || true
  printf '   counted this install on a public tally · skip with --no-count\n'
elif [ "$COUNT" = 0 ]; then
  printf '   install counter skipped\n'
fi

cat <<EOF

  sketchetc $( [ -f "$APP/VERSION" ] && cat "$APP/VERSION" ) is running.

  Grant these when macOS asks (everything degrades gracefully if you don't):
    Accessibility   → window snapping, desktop switching, paste
    Automation      → media controls, app switching
    Calendar        → the meeting widget
    Screen Recording → the screenshot widget

  Press Option+V for clipboard history · click 󰨝 to toggle widgets
  Click 󰏘 → studio for themes · 󰀵 → Settings for notifications
  Updates appear as a 󰚰 pill in the bar. Uninstall: $APP/uninstall.sh

EOF
