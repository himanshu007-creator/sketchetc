#!/bin/bash
# RAM Reclaim SAFE · frees memory without stopping anything the user relies on.
#
# Three rules, unchanged, because this runs unattended from a click and a wrong
# kill costs someone their work: only ORPHANED processes (ppid==1, so the parent
# is already gone), only ones owned by this user, only ones idling under 1% CPU.
#
# What is new: it also reaps sketchetc's OWN strays. Three clip_watch processes
# were found running against a single store on this machine — one per data_dir
# the user had ever had — each firing pasteboard triggers and racing the others.
# Nothing else would ever have cleaned those up, and they are ours to reap.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

free_mb() {
  vm_stat | awk -v ps="$(sysctl -n hw.pagesize)" '
    /Pages free/        {gsub("\\.",""); f=$3}
    /Pages speculative/ {gsub("\\.",""); s=$3}
    END {printf "%d", (f+s)*ps/1048576}'
}

BEFORE=$(free_mb)

# ---- 1. orphaned third-party helpers ----
# The pattern is matched against the command path only, not the whole argument
# line: matching "mcp" anywhere in `args` meant any process with an unrelated
# --flag or file path containing those letters was a candidate.
PIDS=$(ps -axo user=,pid=,ppid=,pcpu=,comm= | awk -v u="$(id -un)" '
  $1 == u && $3 == 1 && $4 < 1.0 {
    cmd = tolower($5)
    if (cmd ~ /mcp|npx|uvx|chromedriver|playwright|puppeteer|headless_shell|headless-shell|esbuild/)
      print $2
  }')

REAPED=0
for pid in $PIDS; do
  kill -TERM "$pid" 2>/dev/null && REAPED=$((REAPED + 1))
done

# ---- 2. our own strays ----
# clip_watch: keep the one the pidfile knows about, reap the rest. bar_drop:
# reap any left behind by an overlapping restart.
OURS=0
LIVE=$(cat "${TMPDIR:-/tmp}/sketchybar_clip_watch.pid" 2>/dev/null)
# If the pidfile is stale, keep the newest watcher rather than reaping the lot:
# clipboard history would otherwise stop capturing until the next tick noticed.
if [ -z "$LIVE" ] || ! kill -0 "$LIVE" 2>/dev/null; then
  LIVE=$(pgrep -f 'plugins/bin/clip_watch' 2>/dev/null | tail -1)
fi
for pid in $(pgrep -f 'plugins/bin/clip_watch' 2>/dev/null); do
  [ "$pid" = "$LIVE" ] && continue
  kill "$pid" 2>/dev/null && OURS=$((OURS + 1))
done
for pid in $(pgrep -f 'plugins/bin/bar_drop' 2>/dev/null | tail -n +2); do
  kill "$pid" 2>/dev/null && OURS=$((OURS + 1))
done

[ "$REAPED" -gt 0 ] && sleep 1.5
for pid in $PIDS; do
  kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
done

# ---- 3. purge ----
# A cancelled password prompt used to be indistinguishable from a successful
# purge, so the notification claimed a reclaim that never happened.
PURGED=1
osascript -e 'do shell script "/usr/sbin/purge; dscacheutil -flushcache; killall -HUP mDNSResponder" with administrator privileges' >/dev/null 2>&1 || PURGED=0

sleep 1.5
AFTER=$(free_mb)
GAINED=$((AFTER - BEFORE))
[ "$GAINED" -lt 0 ] && GAINED=0

if [ "$GAINED" -ge 1024 ]; then
  AMOUNT=$(awk -v m="$GAINED" 'BEGIN {printf "%.1f GB", m/1024}')
  SPOKEN=$(awk -v m="$GAINED" 'BEGIN {printf "%.1f gigabytes", m/1024}')
else
  AMOUNT="${GAINED} MB"
  SPOKEN="${GAINED} megabytes"
fi

# What is actually holding the memory, so the click tells you something you can
# act on rather than just a number. Biggest resident process, ours excluded.
TOP=$(ps -axo rss=,comm= | sort -rn | awk 'NR<=1 {
  n = $2; sub(/.*\//, "", n)
  printf "%s %d MB", n, $1/1024 }')

DETAIL="reaped ${REAPED} orphaned helper(s)"
[ "$OURS" -gt 0 ] && DETAIL="$DETAIL, ${OURS} stray sketchetc helper(s)"
[ "$PURGED" = 0 ] && DETAIL="$DETAIL · purge skipped"
[ -n "$TOP" ] && DETAIL="$DETAIL · largest now $TOP"

"$CONFIG_DIR/plugins/notify.sh" ram "RAM Reclaim" "Freed ${AMOUNT} · ${DETAIL}"
source "$CONFIG_DIR/plugins/settings_lib.sh"
if setting_on voice; then sleep 0.5; say -v Samantha "Reclaimed ${SPOKEN} of RAM. ${REAPED} orphaned helpers reaped." & fi
# only the two memory widgets need redrawing; --update ticks every item at once
sketchybar --set ram updates=on --set cpu updates=on 2>/dev/null
sketchybar --trigger routine 2>/dev/null
