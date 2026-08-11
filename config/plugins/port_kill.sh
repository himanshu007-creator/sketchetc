#!/bin/bash
# port_kill.sh <port> [command-name] · free a port, and only claim success when
# the port is ACTUALLY free.
#
# The old inline `kill $pid` failed in three separate ways, all silent:
#   1. one PID only. The popup deduped listeners by port with awk's !seen[p]++,
#      so a dev server with workers (next/vite/uvicorn --workers, or an IPv4 and
#      IPv6 row owned by different PIDs) had exactly one of its holders killed
#      and the socket stayed bound.
#   2. SIGTERM only, no escalation. Anything that traps or ignores TERM, or is
#      already wedged, survived.
#   3. no verification. `kill` succeeding means the signal was delivered, not
#      that the process died or released the port, and the notification fired on
#      that. `sudo lsof -t -i:PORT | xargs sudo kill -9` worked by hand because
#      it does all three things this script now does.
PORT="$1"
COMM="${2:-process}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"

holders() { lsof -ti "tcp:$PORT" -sTCP:LISTEN 2>/dev/null | sort -u; }
free_now() { [ -z "$(holders)" ]; }

note() { "$CONFIG_DIR/plugins/notify.sh" ports "Dev servers" "$1"; }

case "$PORT" in ''|*[!0-9]*) exit 1 ;; esac

PIDS=$(holders)
if [ -z "$PIDS" ]; then note "Port $PORT was already free"; exit 0; fi

# 1. polite, to every holder
for p in $PIDS; do kill -TERM "$p" 2>/dev/null; done
for _ in 1 2 3 4 5 6; do free_now && { note "Stopped $COMM on port $PORT"; exit 0; }; sleep 0.25; done

# 2. firm, to whatever is still holding it (re-read: children may have re-bound)
for p in $(holders); do kill -KILL "$p" 2>/dev/null; done
for _ in 1 2 3 4; do free_now && { note "Force stopped $COMM on port $PORT"; exit 0; }; sleep 0.25; done

# 3. still bound means a listener this user cannot see or signal, i.e. root owns
# it. That is the one case worth a password prompt, and only ever reached after
# the two cheap attempts above have failed. SKETCHETC_NO_SUDO=1 opts out, which
# is what the tests use so they can never block on a password dialog.
if [ -n "${SKETCHETC_NO_SUDO:-}" ]; then
  note "Could not free port $PORT · needs admin, held by $(holders | tr '\n' ' ')"
  exit 1
fi
REMAIN=$(osascript -e "do shell script \"lsof -ti tcp:$PORT -sTCP:LISTEN 2>/dev/null | tr '\\\\n' ' '\" with administrator privileges" 2>/dev/null)
if [ -n "$REMAIN" ]; then
  osascript -e "do shell script \"kill -9 $REMAIN\" with administrator privileges" >/dev/null 2>&1
  sleep 0.5
fi

if free_now; then note "Force stopped $COMM on port $PORT (needed admin)"
else note "Could not free port $PORT · still held by $(holders | tr '\n' ' ')"; fi
