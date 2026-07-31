#!/bin/bash
# aura accounting · source after hover.sh. CSV: date,points,kind,keys,clicks,agents,prs
source "$CONFIG_DIR/plugins/storage_lib.sh"
AURA_DIR="$(aura_dir)"
mkdir -p "$AURA_DIR" 2>/dev/null

aura_csv() { echo "$AURA_DIR/$(date +%Y-%m).csv"; }

aura_today() {
  # On the 1st of a month this file does not exist yet, and awk over a missing
  # file prints nothing at all rather than 0. That blanked the bar label and the
  # popup's "today" row at every single month rollover.
  local f
  f=$(aura_csv)
  [ -f "$f" ] || { echo 0; return; }
  awk -F, -v d="$(date +%Y-%m-%d)" '$1 == d {s += $2} END {print s + 0}' "$f" 2>/dev/null || echo 0
}

# Everything the popup needs, in ONE awk pass: "today week month streak".
# The popup used to call aura_today + aura_since 7 + aura_since 30 + aura_streak,
# and each of those last three spawned python3 at ~350ms a go: 1.1s of a 1.6s
# popup was interpreter startup. awk on macOS has no mktime, so dates are turned
# into day numbers with the standard days-from-civil formula and compared as ints.
aura_stats() {
  awk -F, -v today="$(date +%Y-%m-%d)" '
    function daynum(s,   y, m, d, era, yoe, doy, doe) {
      y = substr(s,1,4) + 0; m = substr(s,6,2) + 0; d = substr(s,9,2) + 0
      if (m <= 2) y--
      era = int((y >= 0 ? y : y - 399) / 400)
      yoe = y - era * 400
      doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
      doe = yoe * 365 + int(yoe/4) - int(yoe/100) + doy
      return era * 146097 + doe - 719468
    }
    BEGIN { t = daynum(today) }
    /^[0-9]{4}-[0-9]{2}-[0-9]{2},/ {
      n = daynum($1); p = $2 + 0
      if (n == t) todaysum += p
      if (n > t - 7)  week += p
      if (n > t - 30) month += p
      if (p > 0) seen[n] = 1
    }
    END {
      d = (t in seen) ? t : t - 1     # today being empty must not break yesterday
      while (d in seen) { streak++; d-- }
      printf "%d %d %d %d\n", todaysum + 0, week + 0, month + 0, streak + 0
    }
  ' "$AURA_DIR"/*.csv 2>/dev/null || echo "0 0 0 0"
}

aura_streak() { # consecutive days up to today with any points
  python3 - "$AURA_DIR" <<'EOF' 2>/dev/null || echo 0
import csv, glob, sys, datetime
days = set()
for f in glob.glob(sys.argv[1] + '/*.csv'):
    try:
        for row in csv.reader(open(f)):
            try:
                if int(row[1]) > 0: days.add(datetime.date.fromisoformat(row[0]))
            except (ValueError, IndexError): pass
    except OSError: pass
d, n = datetime.date.today(), 0
# today not having points yet should not break yesterday's streak
if d not in days: d -= datetime.timedelta(days=1)
while d in days:
    n += 1
    d -= datetime.timedelta(days=1)
print(n)
EOF
}

aura_since() { # days-back -> total
  python3 - "$1" "$AURA_DIR" <<'EOF'
import csv, glob, sys, datetime
days, root = int(sys.argv[1]), sys.argv[2]
cutoff = datetime.date.today() - datetime.timedelta(days=days)
total = 0
for f in glob.glob(root + '/*.csv'):
    for row in csv.reader(open(f)):
        try:
            if datetime.date.fromisoformat(row[0]) >= cutoff: total += int(row[1])
        except (ValueError, IndexError): pass
print(total)
EOF
}

aura_add() { # points kind keys clicks agents prs
  echo "$(date +%Y-%m-%d),$1,$2,${3:-0},${4:-0},${5:-0},${6:-0}" >> "$(aura_csv)"
}

aura_award() { # points  · celebrate: flash widget + voice + notification
  local P=$1
  aura_add "$P" "${2:-pomodoro}" "${3:-0}" "${4:-0}" "${5:-0}" "${6:-0}"
  "$CONFIG_DIR/plugins/notify.sh" aura "Aura" "+$P aura · locked in 🔥" &
  ( source "$CONFIG_DIR/plugins/settings_lib.sh"; setting_on voice && { sleep 0.5; say -v Samantha "Plus $P aura points. You are locked in."; } ) &
  sketchybar --set aura drawing=on label="+$P ✨" label.color=$PINK icon.color=$PINK
  sketchybar "${ANIM[@]}" --set aura icon.y_offset=4 icon.y_offset=0
  sleep 4
  sketchybar "${ANIM[@]}" --set aura label.color=$WHITE icon.color=$PURPLE
  sketchybar --set aura label="$(aura_today)"
}
