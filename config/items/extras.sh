#!/bin/bash
# Third-party menu bar icons (Docker, Cursor, Dropbox …) mirrored into the bar.
#
# Our bar draws over the native menu bar, which means every icon an app installs
# up there is hidden. That is the single biggest reason to want the native bar
# back. sketchybar's alias component renders those items in place, and a chevron
# collapses them into a tray the way Bartender and Ice do.
#
# Requires Screen Recording permission: aliases are drawn by capturing the real
# menu bar item. Without it, `--query default_menu_items` returns an error and we
# say so once rather than silently showing nothing.
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/user_config.sh"
widget_on extras || return 0



MENU_ITEMS=$(sketchybar --query default_menu_items 2>/dev/null)
if [ -z "$MENU_ITEMS" ] || [[ "$MENU_ITEMS" == *"Permissions not given"* ]]; then
  # one actionable nudge, not a silent no-op
  if [ ! -f "$(uc_runtime .extras_nagged)" ]; then
    touch "$(uc_runtime .extras_nagged)"
    "$PLUGIN_DIR/notify.sh" toggles "Menu bar icons" \
      "Grant Screen Recording to sketchybar to mirror Docker, Cursor and friends" &
  fi
  return 0
fi
rm -f "$(uc_runtime .extras_nagged)"

# macOS' own extras are already covered by our native widgets, so mirroring them
# would just duplicate what the bar shows. Anything else is fair game.
SKIP_RE='^(Control Center|Clock|Siri|Spotlight|TextInputMenuAgent|WiFi|Battery|BentoBox)'
DENY=$(setting extras_deny)

ALIASES=()
while IFS= read -r line; do
  [ -n "$line" ] || continue
  owner=${line%%,*}
  case "$owner" in
    ''|'#'*) continue ;;
  esac
  [[ "$owner" =~ $SKIP_RE ]] && continue
  [ -n "$DENY" ] && [[ ",$DENY," == *",$owner,"* ]] && continue
  ALIASES+=("$line")
done < <(printf '%s\n' "$MENU_ITEMS" | tr -d '"[]' | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$')

[ "${#ALIASES[@]}" -eq 0 ] && return 0

COLLAPSED=$(state_get extras_collapsed)
DRAW=on; CHEV=$ICON_CHEV_LEFT
[ "$COLLAPSED" = "on" ] && { DRAW=off; CHEV=$ICON_CHEV_RIGHT; }

args=(--add item extras.toggle right
      --set extras.toggle icon="$CHEV" icon.color=$PURPLE
        icon.padding_left=6 icon.padding_right=6
        label.drawing=off
        script="$PLUGIN_DIR/extras.sh"
      --subscribe extras.toggle mouse.clicked mouse.entered mouse.exited)

i=0
for a in "${ALIASES[@]}"; do
  i=$((i + 1))
  args+=(--add alias "$a" right
         --set "$a" alias.color=$WHITE
           background.drawing=off
           icon.padding_left=2 icon.padding_right=2
           label.padding_left=0 label.padding_right=0
           drawing=$DRAW
           alias.update_freq=5)
done

sketchybar "${args[@]}" 2>/dev/null
printf '%s\n' "${ALIASES[@]}" > "$CONFIG_DIR/.cache/extras.list" 2>/dev/null
