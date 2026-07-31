#!/bin/bash
# Cleanly back out of sketchetc. Keeps brew packages unless you remove them yourself.
set -e

echo "==> Stopping sketchybar"
brew services stop sketchybar 2>/dev/null || true

echo "==> Removing config symlink"
[ -L "$HOME/.config/sketchybar" ] && rm "$HOME/.config/sketchybar"
BACKUP=$(ls -d "$HOME/.config/sketchybar.bak."* 2>/dev/null | tail -1)
if [ -n "$BACKUP" ]; then
  mv "$BACKUP" "$HOME/.config/sketchybar"
  echo "    restored your previous config from $BACKUP"
fi

cat <<'EOF'

Done — native macOS menu bar is back (it was underneath all along).

Your settings and data are untouched: ~/.config/sketchetc and your data folder
stay put, so reinstalling picks up exactly where you left off.

Optional, if you want the packages gone too:
  brew uninstall sketchybar macmon
  brew untap FelixKratz/formulae
  brew uninstall --cask font-jetbrains-mono-nerd-font
  rm ~/Library/Fonts/sketchybar-app-font.ttf
EOF
