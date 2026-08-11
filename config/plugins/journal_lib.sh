#!/bin/bash
# journal core · tamper-evident daily work log
# Locking model: each day's entry window is that day 12:00 -> next day 12:00.
# Before noon you may still write YESTERDAY (late nights, weekends); at noon
# yesterday locks forever (stub entry if nothing was written).
# conf: root=<dir> only. Personal notes live under root/personal/ (never locked).
source "$CONFIG_DIR/plugins/storage_lib.sh"
JCONF="$HOME/.local/share/sketchetc/journal.conf"
JDRAFT="$HOME/.local/share/sketchetc/journal_draft.md"

jconf() { awk -F= -v k="$1" '$1 == k {print $2}' "$JCONF" 2>/dev/null; }
# the journal lives inside the single data folder
jroot() { data_ready && { data_ensure; journal_root; }; }

jfile_for() { # YYYY-MM-DD -> path
  echo "$(jroot)/${1:0:4}/${1:5:2}/${1:8:2}.md"
}

jtarget_date() { # the day the editor writes for (respects JNOW_H override in tests)
  local hour yesterday
  hour=${JNOW_H:-$(date +%H)}
  yesterday=$(date -v-1d +%Y-%m-%d)
  if [ "${hour#0}" -lt 12 ] && [ ! -f "$(jfile_for "$yesterday")" ]; then
    echo "$yesterday"
  else
    date +%Y-%m-%d
  fi
}

jindex() { echo "$(jroot)/index.log"; }

jchain_append() { # file
  local idx prev hash line
  idx=$(jindex)
  prev=$(tail -1 "$idx" 2>/dev/null | shasum -a 256 | awk '{print $1}')
  [ -s "$idx" ] || prev="genesis"
  hash=$(shasum -a 256 "$1" | awk '{print $1}')
  line="$prev $(date +%Y-%m-%d) ${1#"$(jroot)"/} $hash"
  echo "$line" >> "$idx"
}

jfinalize() { # <YYYY-MM-DD> [content-file] · write that day's entry, chain, lock
  local day f dir src
  day="${1:-$(jtarget_date)}"
  f=$(jfile_for "$day"); dir=$(dirname "$f")
  [ -z "$(jroot)" ] && return 1
  [ -f "$f" ] && return 0   # already locked
  src="${2:-$JDRAFT}"
  # Nothing written means nothing to lock. This used to write a
  # "_(no update logged)_" stub and chflags uchg it, so every weekend and every
  # skipped day left behind an immutable empty file you could not even delete
  # without chflags nouchg first. A day you did not journal is simply absent now.
  [ -s "$src" ] || return 1
  mkdir -p "$dir"
  {
    echo "# $(date -j -f %Y-%m-%d "$day" '+%A, %d %B %Y' 2>/dev/null || echo "$day")"
    echo
    echo "> aura: $(source "$CONFIG_DIR/plugins/aura_lib.sh"; aura_today) · locked $(date '+%d %b %H:%M')"
    echo
    cat "$src"
  } > "$f"
  jchain_append "$f"
  chflags uchg "$f"
  rm -f "$JDRAFT"
  # The entry has banked the day's aura in its header, so the running score
  # starts again from zero — the "reset on final save" half of the aura window.
  ( source "$CONFIG_DIR/plugins/aura_lib.sh"; aura_window_reset )
  sketchybar --set aura label=0 2>/dev/null
  "$CONFIG_DIR/plugins/notify.sh" journal "Journal" "Entry for $day is locked in" &
}

jenforce_noon() { # at/after noon: close yesterday if it was actually written
  local hour yesterday setup_day
  hour=${JNOW_H:-$(date +%H)}
  yesterday=$(date -v-1d +%Y-%m-%d)
  [ "${hour#0}" -ge 12 ] || return 0
  [ -f "$(jfile_for "$yesterday")" ] && return 0
  setup_day=$(date -r "$JCONF" +%Y-%m-%d 2>/dev/null) || return 0
  [[ "$setup_day" > "$yesterday" ]] && return 0   # journal didn't exist yet that day
  # jfinalize now refuses an empty draft, so this writes a file only on days with
  # real content. The aura window still has to close, or a day you chose not to
  # journal would keep accumulating into the next one forever.
  if ! jfinalize "$yesterday"; then
    ( source "$CONFIG_DIR/plugins/aura_lib.sh"
      [ "$(aura_window_start)" -lt "$(date -v-0H -v0M -v0S +%s)" ] && aura_window_reset )
  fi
}

jverify() {
  local idx prev
  idx=$(jindex); prev="genesis"
  [ -s "$idx" ] || { echo "OK (empty)"; return; }
  while read -r p d rel hash; do
    if [ "$p" != "$prev" ]; then echo "TAMPERED chain@$d"; return; fi
    if [ "$(shasum -a 256 "$(jroot)/$rel" 2>/dev/null | awk '{print $1}')" != "$hash" ]; then
      echo "TAMPERED $rel"; return
    fi
    prev=$(echo "$p $d $rel $hash" | shasum -a 256 | awk '{print $1}')
  done < "$idx"
  echo "OK ($(wc -l < "$idx" | tr -d ' ') entries)"
}

jexport() { # day|week|month|year -> markdown (work entries only)
  local days
  case "$1" in day) days=1 ;; week) days=7 ;; month) days=31 ;; year) days=366 ;; esac
  python3 - "$days" "$(jroot)" <<'EOF'
import datetime, pathlib, sys
days, root = int(sys.argv[1]), pathlib.Path(sys.argv[2])
today = datetime.date.today()
out, cur_y, cur_m = [], None, None
for i in range(days - 1, -1, -1):
    d = today - datetime.timedelta(days=i)
    f = root / f"{d.year}" / f"{d.month:02d}" / f"{d.day:02d}.md"
    if not f.exists(): continue
    if d.year != cur_y: out.append(f"# {d.year}"); cur_y, cur_m = d.year, None
    if d.month != cur_m: out.append(f"## {d.strftime('%B')}"); cur_m = d.month
    body = f.read_text()
    body = body.split('\n', 1)[1] if body.startswith('#') else body
    out.append(f"### {d.strftime('%a %d %b')}\n{body.strip()}\n")
print('\n'.join(out) if out else '_(no entries in range)_')
EOF
}
