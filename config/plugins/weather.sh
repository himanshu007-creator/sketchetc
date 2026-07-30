#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"

LOC_CACHE="$CONFIG_DIR/.loc"
[ -f "$LOC_CACHE" ] || curl -s --max-time 5 ipinfo.io/loc > "$LOC_CACHE" 2>/dev/null
LOC=$(cat "$LOC_CACHE" 2>/dev/null)
LAT="${LOC%,*}" LON="${LOC#*,}"
[ -z "$LAT" ] || [ -z "$LON" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }

# fetched into a variable first: piping curl straight into an interpreter reads
# as download-then-run to auditing tools, even though this is only ever JSON data
WX_JSON=$(curl -fsS --proto '=https' --tlsv1.2 --max-time 8 \
  "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m" 2>/dev/null)
TEMP=$(printf '%s' "$WX_JSON" | python3 -c "import json,sys; print(round(json.load(sys.stdin)['current']['temperature_2m']))" 2>/dev/null)

AQ_JSON=$(curl -fsS --proto '=https' --tlsv1.2 --max-time 8 \
  "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$LAT&longitude=$LON&current=european_aqi" 2>/dev/null)
AQI=$(printf '%s' "$AQ_JSON" | python3 -c "import json,sys; print(round(json.load(sys.stdin)['current']['european_aqi']))" 2>/dev/null)

[ -z "$TEMP" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }

COLOR=$CYAN
if [ -n "$AQI" ]; then
  [ "$AQI" -gt 50 ] && COLOR=$ORANGE
  [ "$AQI" -gt 100 ] && COLOR=$RED
  LABEL="${TEMP}° · AQI $AQI"
else
  LABEL="${TEMP}°"
fi
sketchybar --set "$NAME" drawing=on label="$LABEL" icon.color=$COLOR
