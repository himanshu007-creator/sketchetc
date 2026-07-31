#!/bin/bash
# The rules file for whichever project an agent was last working in.
#
# CLAUDE.md / AGENTS.md is the file people keep going back to edit, and finding
# it means remembering which checkout you were in. The transcripts record `cwd`,
# so the most recent session answers that for us. Local files only.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
ROOT="$HOME/.claude/projects"
[ -d "$ROOT" ] || exit 0

CACHE="$CONFIG_DIR/.cache/agent_rules"
if [ "${1:-path}" = "path" ] && [ -f "$CACHE" ] && [ -z "$(find "$CACHE" -mmin +5 2>/dev/null)" ]; then
  cat "$CACHE"; exit 0
fi
mkdir -p "$CONFIG_DIR/.cache" 2>/dev/null

python3 - "$ROOT" <<'PY' 2>/dev/null | tee "$CACHE"
import json, os, sys, glob

files = sorted(glob.glob(os.path.join(sys.argv[1], "*", "*.jsonl")),
               key=lambda f: os.path.getmtime(f), reverse=True)
for path in files[:5]:
    cwd = None
    try:
        with open(path, errors="ignore") as fh:
            for line in fh:
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                if d.get("cwd"):
                    cwd = d["cwd"]          # last one wins: the newest turn
    except OSError:
        continue
    if not cwd:
        continue
    for name in ("CLAUDE.md", "AGENTS.md"):
        p = os.path.join(cwd, name)
        if os.path.isfile(p):
            print(p)
            sys.exit(0)
PY
