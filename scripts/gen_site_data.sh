#!/bin/bash
# Regenerates docs/data/site.json from the live config, so the landing page
# picks up new widgets, themes and icon sets without touching any HTML.
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CFG="$REPO/config"
OUT="$REPO/docs/data/site.json"

python3 - "$REPO" "$CFG" "$OUT" <<'PY'
import json, os, re, sys

repo, cfg, out = sys.argv[1], sys.argv[2], sys.argv[3]

# ---- what each widget replaces (the only hand-kept table) ----
REPLACES = {
    "network":   ("iStat Menus", 12),
    "temps":     ("TG Pro", 10),
    "caffeine":  ("Lungo", 10),
    "clipboard": ("Paste", 30),
    "snap":      ("Magnet", 8),
    "switches":  ("One Switch", 10),
    "shot":      ("CleanShot", 29),
    "bluetooth": ("AirBuddy", 10),
    "speedtest": ("Speedtest app", 0),
    "meeting":   ("Meeter", 0),
    "pomodoro":  ("Flow", 0),
}

# ---- widgets: defaults from widgets.conf, prose from help_open.sh ----
defaults = {}
for line in open(f"{cfg}/widgets.conf"):
    line = line.strip()
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        if k != "max_active":
            defaults[k] = (v == "on")

help_src = open(f"{cfg}/plugins/help_open.sh").read()
descs = dict(re.findall(r'^\s*(\w+)\)\s+echo "([^"]+)"', help_src, re.M))

# ---- icon glyph per widget per iconset ----
ICON_KEY = {
    "spaces": None, "network": "ICON_NET", "caffeine": "ICON_CAF_ON", "ports": "ICON_PORTS",
    "pomodoro": "ICON_POMO", "github": None, "weather": "ICON_WEATHER", "speedtest": "ICON_SPEED",
    "meeting": "ICON_MEETING", "focus": "ICON_FOCUS", "temps": "ICON_TEMPS", "media": "ICON_MEDIA",
    "clipboard": "ICON_CLIP", "aura": "ICON_AURA", "journal": "ICON_JOURNAL", "snap": "ICON_SNAP",
    "switches": "ICON_SWITCHES", "shot": "ICON_SHOT", "bluetooth": "ICON_BT",
}
iconsets = {}
for f in sorted(os.listdir(f"{cfg}/icons")):
    if not f.endswith(".sh"): continue
    name = f[:-3]
    glyphs = {}
    for line in open(f"{cfg}/icons/{f}"):
        for m in re.finditer(r'(ICON_[A-Z_0-9]+)=(\S+)', line):
            glyphs[m.group(1)] = m.group(2).strip('"\'')
    iconsets[name] = glyphs

widgets = []
for key, on in defaults.items():
    ikey = ICON_KEY.get(key)
    rep = REPLACES.get(key)
    widgets.append({
        "key": key,
        "default_on": on,
        "description": descs.get(key, ""),
        "icons": {s: (g.get(ikey, "") if ikey else "1·2·3") for s, g in iconsets.items()},
        "replaces": ({"app": rep[0], "price": rep[1]} if rep else None),
    })
widgets.sort(key=lambda w: (not w["default_on"], w["key"]))

# ---- themes: parse the real palettes ----
ROLES = ["BAR_COLOR", "ITEM_BG_COLOR", "POPUP_BG", "POPUP_BORDER",
         "PINK", "CYAN", "ORANGE", "RED", "PURPLE", "WHITE"]
def hexof(v):
    v = v.replace("0x", "")
    return "#" + (v[2:] if len(v) == 8 else v)
themes = []
for f in sorted(os.listdir(f"{cfg}/themes")):
    if not f.endswith(".sh"): continue
    colors = {}
    for line in open(f"{cfg}/themes/{f}"):
        m = re.match(r'export ([A-Z_]+)=(\S+)', line.strip())
        if m and m.group(1) in ROLES:
            colors[m.group(1)] = hexof(m.group(2).split("#")[0].strip())
    if colors:
        themes.append({"name": f[:-3], "colors": colors})

# ---- release notes: newest section of RELEASES.md ----
notes, cur = [], None
for line in open(f"{repo}/RELEASES.md"):
    if line.startswith("## "):
        if cur: break
        cur = line[3:].strip()
    elif cur and line.strip().startswith("-"):
        notes.append(re.sub(r'\*\*(.+?)\*\*', r'\1', line.strip()[1:].strip()))

total = sum(w["replaces"]["price"] for w in widgets if w["replaces"])
data = {
    "version": open(f"{repo}/VERSION").read().strip(),
    "repo": "himanshu007-creator/sketchetc",
    "replaces_total": total,
    "widgets": widgets,
    "themes": themes,
    "iconsets": sorted(iconsets.keys()),
    "latest": {"version": (cur or "").split("—")[0].strip(), "headline": (cur or ""), "notes": notes},
}
os.makedirs(os.path.dirname(out), exist_ok=True)
json.dump(data, open(out, "w"), indent=1, ensure_ascii=False)
print(f"{out}: {len(widgets)} widgets · {len(themes)} themes · {len(iconsets)} iconsets · ${total} replaced")
PY

# Stamp the version onto the asset URLs. GitHub Pages serves them with
# max-age=600, so without this a release's JS stays invisible to anyone who
# loaded the page in the last ten minutes.
python3 - "$REPO" <<'PY'
import re, sys, pathlib
repo = sys.argv[1]
ver = (pathlib.Path(repo) / "VERSION").read_text().strip()
p = pathlib.Path(repo) / "docs" / "index.html"
t = p.read_text()
new = re.sub(r'\b(style\.css|app\.js|icons\.js)(\?v=[^"\']*)?', lambda m: f"{m.group(1)}?v={ver}", t)
if new != t:
    p.write_text(new)
    print(f"docs/index.html: assets stamped ?v={ver}")
PY
