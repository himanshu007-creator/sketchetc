#!/bin/bash
# Today's agent token usage, read from local session transcripts only.
#
# Claude Code writes a per-message `usage` block into
# ~/.claude/projects/**/*.jsonl alongside `cwd` and `timestamp`. Nothing leaves
# the machine to produce this: it is the same promise as the rest of sketchetc.
#
# Tokens only, deliberately never a cost. Pricing is not in these files, so any
# dollar figure would mean hardcoding rates that go stale and quietly lie.
#
# The format is internal and undocumented. If it changes shape this prints
# nothing and the caller hides the row, which is the right failure: no number is
# better than a wrong one.
#
#   agents_usage.sh          -> "in out cache" totals for today, or empty
#   agents_usage.sh project  -> "tokens  project-name" for the busiest few
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
ROOT="$HOME/.claude/projects"
[ -d "$ROOT" ] || exit 0

# Scanning every recent transcript costs well over a second, and a popup must
# not wait on that. Answers are cached for a minute, which is far finer grained
# than anyone reads a running total.
MODE="${1:-total}"
CACHE="$CONFIG_DIR/.cache/agent_usage_$MODE"
mkdir -p "$CONFIG_DIR/.cache" 2>/dev/null
if [ -f "$CACHE" ] && [ -z "$(find "$CACHE" -mmin +1 2>/dev/null)" ]; then
  cat "$CACHE"; exit 0
fi

python3 - "$ROOT" "$MODE" <<'PY' 2>/dev/null | tee "$CACHE"
import json, os, sys, glob, datetime

root, mode = sys.argv[1], sys.argv[2]
# Timestamps are UTC ("...Z") but "today" means the user's day. At 01:46 local on
# the 1st it is still the 31st in UTC, so comparing the raw string would report
# nothing at all for the first hours of every day.
now = datetime.datetime.now().astimezone()
today_local = now.date()

def is_today(ts):
    try:
        d = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except Exception:
        return False
    return d.astimezone().date() == today_local
tot_in = tot_out = tot_cache = 0
per_project = {}

# only files touched in the last day can hold today's messages
cutoff = datetime.datetime.now().timestamp() - 36 * 3600
files = [f for f in glob.glob(os.path.join(root, "*", "*.jsonl"))
         if os.path.getmtime(f) > cutoff]

for path in files:
    try:
        with open(path, errors="ignore") as fh:
            for line in fh:
                try:
                    d = json.loads(line)
                except Exception:
                    continue          # a partial trailing line is normal, skip it
                if not is_today(d.get("timestamp") or ""):
                    continue
                u = (d.get("message") or {}).get("usage")
                if not isinstance(u, dict):
                    continue
                i = int(u.get("input_tokens") or 0)
                o = int(u.get("output_tokens") or 0)
                c = int(u.get("cache_read_input_tokens") or 0) + \
                    int(u.get("cache_creation_input_tokens") or 0)
                tot_in += i; tot_out += o; tot_cache += c
                cwd = d.get("cwd") or ""
                name = os.path.basename(cwd) or "unknown"
                per_project[name] = per_project.get(name, 0) + i + o + c
    except OSError:
        continue

if tot_in == tot_out == tot_cache == 0:
    sys.exit(0)                        # nothing today: caller hides the row

def human(n):
    if n >= 1_000_000: return "%.1fM" % (n / 1_000_000)
    if n >= 1_000:     return "%.0fk" % (n / 1_000)
    return str(n)

if mode == "project":
    for name, n in sorted(per_project.items(), key=lambda kv: -kv[1])[:3]:
        print("%s\t%s" % (human(n), name))
else:
    print("%s %s %s" % (human(tot_in), human(tot_out), human(tot_cache)))
PY
