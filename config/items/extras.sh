#!/bin/bash
# Third-party menu bar icons (Docker, Cursor, Dropbox …) brought into the bar —
# and, unlike before, actually clickable.
#
# Our bar draws over the native menu bar, so every icon an app installs up there
# is hidden. That is the single biggest reason someone would want the native bar
# back, which makes this the widget that has to work.
#
# This used to use sketchybar's `alias` component. An alias is a periodically
# re-captured BITMAP of the real item: it needed the Screen Recording grant (never
# given here, so the widget silently drew nothing at all), it cost one screen
# capture per icon every 5 seconds, and it could never be clicked, because
# sketchybar has no way to activate the item it photographed.
#
# Now: bin/menubar_extras enumerates the real extras through Accessibility, we
# draw our own themed items with the app's own glyph, and a click sends AXPress to
# the genuine status item so the app's real dropdown opens. Accessibility only —
# the grant the bar already holds — and no screen capture anywhere.
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/user_config.sh"
widget_on extras || return 0

HELPER="$CONFIG_DIR/plugins/bin/menubar_extras"
[ -x "$HELPER" ] || return 0

# app-name -> glyph, the same map front_app.sh uses. It already knows Docker
# Desktop, Cursor and ~1600 others; anything unknown falls back to :default:.
source "$CONFIG_DIR/plugins/icon_map_fn.sh"

DENY=$(setting extras_deny)

APPS=()
PIDS=()
while IFS=$'\t' read -r pid name; do
  [ -n "$name" ] || continue
  # comma-separated app names the user never wants mirrored
  [ -n "$DENY" ] && [[ ",$DENY," == *",$name,"* ]] && continue
  PIDS+=("$pid")
  APPS+=("$name")
done < <("$HELPER" list 2>/dev/null)

if [ "${#APPS[@]}" -eq 0 ]; then
  # Accessibility missing is the one failure worth naming: everything else just
  # means no app happens to have an icon right now.
  if ! "$HELPER" list >/dev/null 2>&1 && [ ! -f "$(uc_runtime .extras_nagged)" ]; then
    touch "$(uc_runtime .extras_nagged)"
    "$PLUGIN_DIR/notify.sh" toggles "Menu bar icons" \
      "Grant Accessibility to sketchybar to show Docker, Cursor and friends" &
  fi
  return 0
fi
rm -f "$(uc_runtime .extras_nagged)"

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
for idx in "${!APPS[@]}"; do
  name="${APPS[$idx]}"
  i=$((i + 1))
  __icon_map "$name"
  # AXPress goes through System Events on purpose: the Accessibility grant is per
  # client binary, so the same call from our own helper returns -25204 while
  # System Events — already trusted, already used for snapping — just works.
  args+=(--add item "extras.app.$i" right
         --set "extras.app.$i" icon="$icon_result"
           icon.font="sketchybar-app-font:Regular:16.0"
           icon.color=$WHITE
           icon.padding_left=6 icon.padding_right=6
           label.drawing=off
           drawing=$DRAW
           click_script="osascript -e 'tell application \"System Events\" to tell process \"$name\" to perform action \"AXPress\" of menu bar item 1 of menu bar 2' >/dev/null 2>&1"
           script="$PLUGIN_DIR/popup_row.sh"
         --subscribe "extras.app.$i" mouse.entered mouse.exited)
done

sketchybar "${args[@]}" 2>/dev/null
mkdir -p "$CONFIG_DIR/.cache" 2>/dev/null
printf '%s\n' "${APPS[@]}" > "$CONFIG_DIR/.cache/extras.list" 2>/dev/null
