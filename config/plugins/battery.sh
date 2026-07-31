#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
source "$CONFIG_DIR/plugins/popup_lib.sh"
hover
close_popup_on_exit

if [ "$SENDER" = "mouse.clicked" ]; then
  PM=$(pmset -g batt)
  TIME_LEFT=$(printf '%s' "$PM" | grep -Eo '[0-9]+:[0-9]+ remaining' | head -1)
  if [ -z "$TIME_LEFT" ]; then
    printf '%s' "$PM" | grep -q 'AC Power' && TIME_LEFT="on AC power" || TIME_LEFT="calculating…"
  fi

  # Health barely moves day to day and ioreg is not free, so it is cached for a
  # day. This is the coconutBattery answer: cycles, how much of the original
  # capacity is left, and whether the pack is still considered healthy.
  HEALTH_CACHE="$CONFIG_DIR/.cache/battery_health"
  if [ ! -f "$HEALTH_CACHE" ] || [ -n "$(find "$HEALTH_CACHE" -mmin +1440 2>/dev/null)" ]; then
    mkdir -p "$CONFIG_DIR/.cache" 2>/dev/null
    # Read the figures Apple itself reports rather than recomputing them from
    # ioreg: deriving capacity from DesignCapacity came out 6 points below what
    # System Settings shows, and a health number that disagrees with macOS is
    # worse than no health number. system_profiler takes ~1-2s, which is exactly
    # why this is cached for a day.
    system_profiler SPPowerDataType 2>/dev/null | awk -F': *' '
      /Cycle Count/       {cyc = $2}
      /Condition/         {cond = $2}
      /Maximum Capacity/  {gsub(/%/, "", $2); cap = $2}
      END { printf "%d %d %s\n", cyc + 0, cap + 0, (cond ? cond : "Unknown") }' > "$HEALTH_CACHE" 2>/dev/null
  fi
  read -r CYCLES HEALTH COND < "$HEALTH_CACHE" 2>/dev/null

  HCOL=$CYAN
  [ "${HEALTH:-100}" -lt 80 ] 2>/dev/null && HCOL=$ORANGE
  [ "${COND:-Normal}" != "Normal" ] && HCOL=$RED

  pop_begin battery "$POP_W"
  pop_head "Battery"
  pop_row  time 󰥔 "$TIME_LEFT" "" "$ORANGE"
  pop_kv   cycles 󰑓 "cycles"    "${CYCLES:-?}"     "$ORANGE"
  pop_kv   health 󰁹 "health"    "${HEALTH:-?}%"    "$HCOL"
  pop_kv   cond   󰗠 "condition" "${COND:-?}"       "$HCOL"
  pop_end
  toggle_popup
  exit 0
fi

BATT=$(pmset -g batt)
PCT=$(echo "$BATT" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
[ -z "$PCT" ] && exit 0

if echo "$BATT" | grep -q 'AC Power'; then
  ICON=$ICON_BAT_CHG COLOR=$CYAN
else
  case $PCT in
    9[0-9]|100) ICON=$ICON_BAT_100 ;;
    [6-8][0-9]) ICON=$ICON_BAT_75 ;;
    [3-5][0-9]) ICON=$ICON_BAT_50 ;;
    [1-2][0-9]) ICON=$ICON_BAT_25 ;;
    *)          ICON=$ICON_BAT_10 ;;
  esac
  COLOR=$ORANGE
  [ "$PCT" -le 20 ] && COLOR=$RED
fi

sketchybar --set "$NAME" icon="$ICON" icon.color=$COLOR label="${PCT}%"
