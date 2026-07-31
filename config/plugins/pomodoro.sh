#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover

STATE="${TMPDIR:-/tmp}/sketchybar_pomo"
SNAP="${TMPDIR:-/tmp}/sketchybar_pomo_snap"

if [ "$SENDER" = "mouse.clicked" ]; then
  if [ -f "$STATE" ]; then
    rm -f "$STATE" "$SNAP"
  else
    echo $(( $(date +%s) + 1500 )) > "$STATE"   # 25 min
    # snapshot activity counters + PRs for aura scoring at completion
    read -r _ _ CLICKS _ _ KEYS < <("$CONFIG_DIR/plugins/bin/mouse_info")
    PRS=$(gh search prs --author=@me --created="$(date +%Y-%m-%d)" --json number -q length 2>/dev/null || echo 0)
    echo "$KEYS $CLICKS ${PRS:-0}" > "$SNAP"
  fi
fi

if [ ! -f "$STATE" ]; then
  sketchybar --set "$NAME" icon=$ICON_POMO icon.color=$WHITE label.drawing=off width=dynamic
  exit 0
fi

REM=$(( $(cat "$STATE") - $(date +%s) ))
if [ "$REM" -le 0 ]; then
  rm -f "$STATE"
  "$CONFIG_DIR/plugins/notify.sh" pomodoro "Pomodoro" "25 minutes done · take a break"
  sketchybar --set "$NAME" icon=$ICON_POMO icon.color=$WHITE label.drawing=off width=dynamic

  # ---- aura scoring for this pomodoro ----
  source "$CONFIG_DIR/plugins/aura_lib.sh"
  read -r K0 C0 P0 < <(cat "$SNAP" 2>/dev/null || echo "0 0 0"); rm -f "$SNAP"
  read -r _ _ C1 _ _ K1 < <("$CONFIG_DIR/plugins/bin/mouse_info")
  AGENTS=$(ps -axo comm= | grep -cE '(^|/)(claude|codex|gemini)$')
  P1=$(gh search prs --author=@me --created="$(date +%Y-%m-%d)" --json number -q length 2>/dev/null || echo 0)
  DK=$((K1 - K0)); DC=$((C1 - C0)); DP=$(( ${P1:-0} - P0 )); [ "$DP" -lt 0 ] && DP=0
  KP=$((DK / 100)); [ "$KP" -gt 50 ] && KP=50
  CP=$((DC / 50));  [ "$CP" -gt 20 ] && CP=20
  AP=$((AGENTS * 10)); [ "$AP" -gt 30 ] && AP=30
  POINTS=$((50 + KP + CP + AP + DP * 25)); [ "$POINTS" -gt 200 ] && POINTS=200
  aura_award "$POINTS" pomodoro "$DK" "$DC" "$AGENTS" "$DP"
  exit 0
fi

COLOR=$PINK
[ "$REM" -le 60 ] && COLOR=$RED
sketchybar --set "$NAME" icon=$ICON_POMO icon.color=$COLOR label.drawing=on width=76 \
  label="$(printf '%02d:%02d' $((REM / 60)) $((REM % 60)))" label.color=$COLOR
