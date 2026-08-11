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

# Only the frontmost process is inspected. Walking every window of every visible
# process measured 2.24s on a normal working session against an update_freq of 3,
# so it never finished before the next tick and got steadily worse as windows
# accumulated through the day. Frontmost-only measures 0.14s and finds the same
# window, because a window can only enter fullscreen while its app is frontmost.
RESULT=$(osascript <<AS 2>&1
set converted to 0
tell application "System Events"
  try
    set p to first application process whose frontmost is true
  on error
    return 0
  end try
  try
    repeat with w in windows of p
      if value of attribute "AXFullScreen" of w is true then
        set value of attribute "AXFullScreen" of w to false
        delay 1.4
        set position of w to {0, $BARH}
        set size of w to {$W, $H - $BARH}
        set converted to converted + 1
      end if
    end repeat
  on error errMsg
    return "ERR: " & errMsg
  end try
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
