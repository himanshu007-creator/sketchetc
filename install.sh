#!/bin/bash
# sketchetc — one-shot install of my SketchyBar Vice City setup on a fresh Mac.
set -e
REPO="$(cd "$(dirname "$0")" && pwd)"

echo "==> Installing sketchybar + fonts"
brew tap FelixKratz/formulae 2>/dev/null || true
brew trust felixkratz/formulae 2>/dev/null || true   # newer brew requires trusting third-party taps
brew list sketchybar &>/dev/null || brew install sketchybar
brew list macmon &>/dev/null || brew install macmon      # temps + fan RPM widget
brew list pngpaste &>/dev/null || brew install pngpaste  # clipboard image capture
brew list switchaudio-osx &>/dev/null || brew install switchaudio-osx  # audio output switcher
brew list blueutil &>/dev/null || brew install blueutil  # bluetooth widget
brew tap koekeishiya/formulae 2>/dev/null || true
brew trust koekeishiya/formulae 2>/dev/null || true
brew list skhd &>/dev/null || brew install koekeishiya/formulae/skhd  # Ctrl+V clipboard hotkey
brew list --cask font-jetbrains-mono-nerd-font &>/dev/null || brew install --cask font-jetbrains-mono-nerd-font
if [ ! -f "$HOME/Library/Fonts/sketchybar-app-font.ttf" ]; then
  # a fresh macOS account has no ~/Library/Fonts yet, and curl will not create it.
  # Under set -e that aborted the whole install before the bar ever started.
  mkdir -p "$HOME/Library/Fonts"
  curl -fsSL "https://github.com/kvndrsslr/sketchybar-app-font/releases/latest/download/sketchybar-app-font.ttf" \
    -o "$HOME/Library/Fonts/sketchybar-app-font.ttf" \
    || echo "  ! app icon font download failed, app icons will fall back"
fi

echo "==> Linking config"
if [ -e "$HOME/.config/sketchybar" ] && [ ! -L "$HOME/.config/sketchybar" ]; then
  mv "$HOME/.config/sketchybar" "$HOME/.config/sketchybar.bak.$(date +%s)"
fi
mkdir -p "$HOME/.config"
ln -sfn "$REPO/config" "$HOME/.config/sketchybar"
chmod +x "$REPO/config/sketchybarrc" "$REPO/config/colors.sh" "$REPO/config/items/"* "$REPO/config/plugins/"*

# Native menu bar stays VISIBLE: macOS reserves the top strip so windows tile
# below it, and sketchybar (topmost=on) draws over the native bar in that strip.
echo "==> Ensuring native menu bar is visible (reserves bar space)"
defaults write NSGlobalDomain _HIHideMenuBar -bool false
killall Finder 2>/dev/null || true

echo "==> Enabling ctrl+1..4 desktop-switch hotkeys"
# a convenience, not a requirement: defaults, plistlib or activateSettings failing
# here should cost the shortcuts, not leave someone without a menu bar
hotkeys() {
TMP=$(mktemp -d)
defaults export com.apple.symbolichotkeys "$TMP/shk.plist"
python3 - "$TMP/shk.plist" <<'EOF'
import plistlib, sys
p = sys.argv[1]
with open(p, 'rb') as f: d = plistlib.load(f)
hk = d.setdefault('AppleSymbolicHotKeys', {})
for i, key in enumerate([118, 119, 120, 121]):  # Switch to Desktop 1-4
    hk[str(key)] = {'enabled': True, 'value': {'parameters': [65535, 18 + i, 262144], 'type': 'standard'}}
with open(p, 'wb') as f: plistlib.dump(d, f)
EOF
defaults import com.apple.symbolichotkeys "$TMP/shk.plist"
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
}
hotkeys || echo "  ! could not set the ctrl+1..4 desktop hotkeys, everything else is fine"

echo "==> Compiling Swift helpers (outside-click close, meetings widget)"
if command -v swiftc >/dev/null; then
  "$REPO/config/plugins/build.sh"
else
  echo "   swiftc not found - skipping (install Xcode command line tools for windows and pickers)"
fi

echo "==> Option+V clipboard hotkey (skhd)"
mkdir -p "$HOME/.config/skhd"
grep -q clipboard_choose "$HOME/.config/skhd/skhdrc" 2>/dev/null || \
  echo 'alt - v : CONFIG_DIR=$HOME/.config/sketchybar $HOME/.config/sketchybar/plugins/clipboard_choose.sh' >> "$HOME/.config/skhd/skhdrc"
skhd --install-service 2>/dev/null || true
skhd --start-service 2>/dev/null || true

echo "==> Starting service"
brew services restart sketchybar

cat <<'EOF'

Done. Two one-time permission grants macOS will ask for:
  1. Accessibility (space switching):  System Settings → Privacy & Security → Accessibility → sketchybar
  2. Automation (media / app switching): allow "sketchybar wants to control ..." prompts
If the native menu bar still shows: System Settings → Control Center →
"Automatically hide and show the menu bar" → Always.
EOF
