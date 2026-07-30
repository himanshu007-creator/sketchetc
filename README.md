# sketchetc

A themeable, fully interactive macOS menu bar built on [SketchyBar](https://felixkratz.github.io/SketchyBar/).
Free forever, source visible to everyone — and it replaces a small pile of paid menu bar apps.

![topbar](assets/topbar.png)

<p>
<a href="https://github.com/himanshu007-creator/sketchetc/releases/latest"><img alt="latest release" src="https://img.shields.io/github/v/release/himanshu007-creator/sketchetc?style=flat&label=release&color=ff6ec7&labelColor=1b0d33&display_name=tag&sort=semver"></a>
<a href="https://himanshu007-creator.github.io/sketchetc"><img alt="site" src="https://img.shields.io/badge/site-sketchetc-ff6ec7?style=flat"></a>
<img alt="installs" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.counterapi.dev%2Fv1%2Fsketchetc%2Finstalls%2F&query=%24.count&label=installs&color=0bd3d3&labelColor=1b0d33&style=flat">
<img alt="stars" src="https://img.shields.io/github/stars/himanshu007-creator/sketchetc?style=flat&logo=github&logoColor=white&label=stars&color=9b5de5&labelColor=1b0d33">
<img alt="forks" src="https://img.shields.io/github/forks/himanshu007-creator/sketchetc?style=flat&logo=github&logoColor=white&label=forks&color=555&labelColor=1b0d33">
<img alt="visits" src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.counterapi.dev%2Fv1%2Fsketchetc%2Fvisits%2F&query=%24.count&label=site%20visits&color=ffa552&labelColor=1b0d33">
<img alt="last commit" src="https://img.shields.io/github/last-commit/himanshu007-creator/sketchetc?style=flat&color=555">
<a href="https://scorecard.dev/viewer/?uri=github.com/himanshu007-creator/sketchetc"><img alt="OpenSSF Scorecard" src="https://api.scorecard.dev/projects/github.com/himanshu007-creator/sketchetc/badge"></a>
<a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-CC%20BY--NC--ND%204.0-0bd3d3?style=flat&labelColor=1b0d33"></a>
</p>

## Install

```bash
curl -fsSL https://himanshu007-creator.github.io/sketchetc/install.sh | bash
```

<!-- INSTALLER:START -->
<details>
<summary><b>Read the installer before you run it</b> (recommended — it is 137 lines, no obfuscation)</summary>

```bash
#!/bin/bash
# sketchetc installer · curl -fsSL https://himanshu007-creator.github.io/sketchetc/install.sh | bash
# Idempotent: first run installs, later runs upgrade in place.
set -euo pipefail

REPO_URL="https://github.com/himanshu007-creator/sketchetc.git"
BRANCH="${SKETCHETC_CHANNEL:-production}"
APP="$HOME/.local/share/sketchetc/app"
DRY=0
COUNT=1
for a in "$@"; do
  [ "$a" = "--dry-run" ] && DRY=1
  [ "$a" = "--no-count" ] && COUNT=0
done
[ -n "${SKETCHETC_NO_TELEMETRY:-}" ] && COUNT=0

say()  { printf '[38;5;213m==>[0m %s
' "$1"; }
warn() { printf '[38;5;215m  ! [0m%s
' "$1"; }
run()  { if [ "$DRY" = 1 ]; then printf '   would run: %s
' "$*"; else "$@"; fi }

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
  if brew list "$f" &>/dev/null; then printf '   have %s
' "$f"; else run brew install "$f"; fi
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
if [ -d "$APP/.git" ]; then
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
  printf '   counted this install on a public tally · skip with --no-count
'
elif [ "$COUNT" = 0 ]; then
  printf '   install counter skipped
'
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
```

</details>

**Verify it instead of trusting us:**

```bash
curl -fsSLO https://himanshu007-creator.github.io/sketchetc/install.sh
shasum -a 256 install.sh    # expect f9dfd3671a023d8a7d48f5aa7d50756c60f6a6239864080072699e7dfaf48cfc
less install.sh             # read it
bash install.sh
```

**Pin to a release** (immutable — this exact commit, forever):

```bash
curl -fsSL https://raw.githubusercontent.com/himanshu007-creator/sketchetc/v1.2.2/docs/install.sh -o install.sh
shasum -a 256 install.sh && bash install.sh
```
<!-- INSTALLER:END -->

Re-running the same command upgrades in place. Prefer git? `git clone -b production …` then `./install.sh`.
Skip the anonymous install counter with `--no-count` or `SKETCHETC_NO_TELEMETRY=1`.



## Replaces ~$120 of paid apps

| Widget | What it does | Replaces |
|---|---|---|
| 󰛴 Network speed | live ↓/↑, click → top-5 bandwidth hogs | iStat Menus ($12) |
| 󰔏 Temps | CPU °C + fan RPM (auto-hides RPM on fanless Macs) | TG Pro ($10) |
| 󰅶 Caffeinate | one-click keep-awake toggle | Lungo ($10) |
| 󰓅 Speedtest | click → Apple's `networkQuality`, result in the bar | Speedtest app |
| 󰔛 Pomodoro | click → 25:00 countdown, spoken finish | Flow ($) |
| 󰤙 Meetings | "Standup in 8m" appears <60 min out, click joins the Zoom/Meet | Meeter ($) |
| 󰊤 GitHub | PRs awaiting your review · your open PRs, click to open | — |
| 󰙨 Dev ports | running dev servers (3000, 5173, 8080…), click to kill | — |
| 󱂬 Window snapping | halves, thirds, maximize, center the frontmost window | Magnet ($8) |
| 󰨚 Quick switches | dark mode, hide desktop icons, empty Trash, screensaver | One Switch ($10) |
| 󰹑 Screenshots | area, window, full screen, 5s timer — every shot also lands on the clipboard, ready to paste | CleanShot ($29) |
| 󰂯 Bluetooth | paired devices + battery, click to connect | AirBuddy ($10) |
| 󰕾 Audio switching | pick output device right in the volume popup | SoundSource ($47) |
| 󰚩 AI agents | running claude/codex/gemini sessions with uptime | — |
| 󰃢 Clear RAM | reaps orphaned helpers + purge, then *speaks* the result | CleanMyMac-ish |
| 󰖙 Weather | temp + AQI, color-coded | paid weather widgets |
| + | spaces, front-app switcher, media controls + progress, volume slider, battery health, calendar | — |

| 󰅍 Clipboard history | **Option+V anywhere** → native picker of your last 5 copies (text + image thumbnails), arrow keys + Enter or click to paste — works in terminals too | Paste ($30/yr) / Maccy |
| 󱠇 Aura points | pomodoros scored on real activity (keys/clicks/agents/PRs) → spoken awards, shareable PNG cards ([how](AURA.md)) | — |
| 󱓧 Journal | tamper-evident daily work log: immutable files + hash chain, export any timeframe ([how](JOURNAL.md)) | — |

Everything is **toggleable** from the 󰨝 popover — turn off what you don't want,
it vanishes from the bar. Icons come in three sets (nerd / minimal / emoji),
switchable next to the theme dots in the 󰏘 popover.

## Themes (hot-swap from the 󰀵 menu)

| | |
|---|---|
| **Vice City** ![](assets/theme-vice-city.png) | **Cyberpunk** ![](assets/theme-cyberpunk.png) |
| **Matrix** ![](assets/theme-matrix.png) | **Catppuccin** ![](assets/theme-catppuccin.png) |
| **Miami Sunset** ![](assets/theme-miami-sunset.png) | *[add yours →](WIDGETS.md)* |

**Theme Studio** (󰏘 → studio) gives every color role a native picker. Built-in
themes are read only: Duplicate one, then edit and Apply. The **icon set is a
global setting** (six of them: nerd, minimal, outline, retro, emoji, plain) and
lives in the studio footer, so it applies across every theme. A theme is a 12-line file in
`config/themes/`, and every widget uses palette roles, so any theme restyles the
whole bar including popups.

## Feel

- **One popup at a time**, closes on outside click / app switch / mouse-out
- **Reserved space** — windows tile below the bar, never behind it
- **Fullscreen guard** — fullscreening an app converts it to fill-below-the-bar (toggleable)
- Hover glows, bounce animations, all in the active theme's colors
- **Fixed widget widths** — changing numbers never reflow the bar
- **Settings** (󰀵 → Settings…) — silence any notification category, turn sounds
  or spoken announcements off, control screenshot-to-clipboard. Stored in
  `config/settings.conf`, editable by hand too.
- **Autostarts** on login (brew services / launchd)

## Permissions

Grant the permissions macOS asks for (Accessibility → space switching + fullscreen
guard; Calendar → meetings widget). Everything degrades gracefully if you decline.

## Leave anytime

- **󰀵 menu → "Revert to macOS bar"** — confirmation dialog, then the native bar
  is back instantly (`brew services start sketchybar` returns you).
- `./uninstall.sh` — full clean removal.

## Extend

`WIDGETS.md` — a widget is ~30 lines of bash in two files. `ROADMAP.md` — what's
next (album-art tinting, per-agent token burn, more themes — PRs welcome).

## Credit

Built on [FelixKratz/SketchyBar](https://github.com/FelixKratz/SketchyBar) ·
app icons from [sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font) ·
temps via [macmon](https://github.com/vladkens/macmon).

## License

[CC BY-NC-ND 4.0](LICENSE) — plain English version: [LICENSE-SUMMARY.md](LICENSE-SUMMARY.md).
Free to use forever, and it will never be sold.
Share it and credit it freely; do not charge for it, and do not publish a
modified copy as your own release. Configuring your own bar, writing your own
themes, and forking to open a pull request here are all fine.
