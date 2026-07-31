#!/bin/bash
# Builds the widget guide data (current iconset icons + live active states +
# theme colors) and opens the themed help window. Run detached.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
export CONFIG_DIR
source "$CONFIG_DIR/colors.sh"

desc() {
  case "$1" in
    spaces)    echo "Desktop spaces 1-4. Click a number to switch desktops (uses the system ctrl+number shortcuts)." ;;
    network)   echo "Live download and upload speed, sampled every 2 seconds. Click for the top 5 processes using your bandwidth." ;;
    caffeine)  echo "Keeps the Mac and display awake. Click to toggle. Only tracks its own keep-awake, so other tools' caffeinate sessions are left alone." ;;
    ports)     echo "Every dev server you are running (ports 1024-9999, system noise filtered). Click a row to kill that process, with a notification when it stops." ;;
    pomodoro)  echo "A 25 minute focus timer. Click to start or stop. Finishing a pomodoro earns aura points scored on your real activity during it." ;;
    github)    echo "PRs awaiting your review and your open PRs. Click a row to open it on GitHub. Refreshes every 5 minutes." ;;
    weather)   echo "Current temperature and air quality index for your location, color coded by AQI band. Refreshes every 30 minutes." ;;
    speedtest) echo "One-click internet speed test using Apple's built-in networkQuality. Result shows in the bar for 10 seconds and arrives as a notification." ;;
    meeting)   echo "Shows your next calendar meeting when it is under an hour away, pulsing when imminent. Click to join the Zoom, Meet or Teams link." ;;
    focus)     echo "Toggles Do Not Disturb. Needs a macOS Shortcut named Toggle Focus (two clicks to create in the Shortcuts app)." ;;
    temps)     echo "CPU temperature, plus fan RPM on Macs that have a fan. Reads via macmon, no admin access needed." ;;
    media)     echo "Now playing from Spotify or Music. Click to play or pause, right-click for previous, next and a progress bar." ;;
    extras)    echo "Menu bar icons from other apps (Docker, Cursor, Dropbox) mirrored into the bar, with a chevron that collapses them into a tray. Needs Screen Recording permission." ;;
    clipboard) echo "Your last 20 copies, text and images. Press Option+V anywhere for the picker, then type to filter. Arrow keys and Enter to paste, image previews included. Prompts live here too." ;;
    aura)      echo "Your effort score. Pomodoros and real activity earn points. Click for totals and shareable PNG cards via Export." ;;
    journal)   echo "Daily work log that locks each day at noon the next day (hash-chained, tamper-evident), plus a personal scratchpad with autosave." ;;
    snap)      echo "Window snapping: halves, thirds, maximize, center for the frontmost window. Replaces Magnet." ;;
    switches)  echo "Quick toggles: dark mode, hide desktop icons, empty Trash, screensaver. Replaces One Switch." ;;
    shot)      echo "Screenshot menu: area, window, full screen, 5s timer, straight to clipboard, and area to text with on-device OCR. A free CleanShot-lite." ;;
    bluetooth) echo "Paired Bluetooth devices with battery where reported. Click a device to connect or disconnect." ;;
  esac
}

TSV="${TMPDIR:-/tmp}/sketchetc_help.tsv"
: > "$TSV"
for w in spaces network caffeine ports pomodoro github weather speedtest meeting focus temps media clipboard aura journal snap switches shot bluetooth; do
  case "$w" in
    spaces) I="1·2·3" ;; network) I="$ICON_NET" ;; caffeine) I="$ICON_CAF_ON" ;;
    ports) I="$ICON_PORTS" ;; pomodoro) I="$ICON_POMO" ;; github) I="󰊤" ;;
    weather) I="$ICON_WEATHER" ;; speedtest) I="$ICON_SPEED" ;; meeting) I="$ICON_MEETING" ;;
    focus) I="$ICON_FOCUS" ;; temps) I="$ICON_TEMPS" ;; media) I="$ICON_MEDIA" ;;
    clipboard) I="$ICON_CLIP" ;; aura) I="$ICON_AURA" ;; journal) I="$ICON_JOURNAL" ;;
    snap) I="$ICON_SNAP" ;; switches) I="$ICON_SWITCHES" ;; shot) I="$ICON_SHOT" ;; bluetooth) I="$ICON_BT" ;;
  esac
  A=0; widget_on "$w" && A=1
  printf '%s\t%s\t%s\t%s\n' "$w" "$I" "$A" "$(desc "$w")" >> "$TSV"
done

exec "$CONFIG_DIR/plugins/bin/help_win" "$TSV" "$BAR_COLOR" "$ITEM_BG_COLOR" "$PINK" "$CYAN"
