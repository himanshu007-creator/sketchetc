#!/bin/bash
# Fullscreen guard: native fullscreen always spans every pixel (nothing can
# reserve space there), so convert any fullscreen window into a fill-below-the-
# bar window. Toggle off via the apple menu (flag file) for real fullscreen.
# Requires the Accessibility grant for sketchybar · prompts once if missing.
source "${CONFIG_DIR:-$HOME/.config/sketchybar}/plugins/user_config.sh"
[ "$(state_get fs_guard)" = "off" ] && exit 0

LOG="$(uc_runtime fs_guard.log)"
PROMPTED="$(uc_runtime .fs_guard_prompted)"
BARH=30

# screen size from our own helper · no Automation/Finder permission needed
read -r _ _ _ H W < <("$CONFIG_DIR/plugins/bin/mouse_info") || exit 0
[ -z "$W" ] && exit 0

RESULT=$(osascript <<AS 2>&1
set converted to 0
tell application "System Events"
  repeat with p in (application processes whose visible is true)
    repeat with w in windows of p
      try
        if value of attribute "AXFullScreen" of w is true then
          set value of attribute "AXFullScreen" of w to false
          delay 1.4
          set position of w to {0, $BARH}
          set size of w to {$W, $H - $BARH}
          set converted to converted + 1
        end if
      on error errMsg
        return "ERR: " & errMsg
      end try
    end repeat
  end repeat
end tell
return converted
AS
)

echo "$(date '+%H:%M:%S') $RESULT" > "$LOG"

case "$RESULT" in
  *"not allowed"*|*1002*|*25211*|*1719*)
    if [ ! -f "$PROMPTED" ]; then
      touch "$PROMPTED"
      "$CONFIG_DIR/plugins/notify.sh" toggles "SketchyBar needs Accessibility" "Enable sketchybar under Privacy & Security → Accessibility, then fullscreen apps will auto-fit below the bar"
      open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    fi
    ;;
  ERR:*) ;;                 # non-permission AX hiccup · logged, retry next tick
  *) rm -f "$PROMPTED" ;;
esac
exit 0
