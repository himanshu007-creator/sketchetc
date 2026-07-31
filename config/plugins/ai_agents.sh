#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"

# the agents people actually leave running; click a row to stop a runaway one
AGENT_RE='(^|/| )(claude|codex|gemini|cursor-agent|aider|ollama|opencode|amp)$'
hover
close_popup_on_exit

if [ "$SENDER" = "mouse.clicked" ]; then
  args=(--remove '/ai_agents.row\..*/'
        --add item ai_agents.row.head popup.ai_agents
        --set ai_agents.row.head icon.drawing=off background.drawing=off label="Running agents"
          label.color=$PURPLE label.font="$HEAD_FONT"
          label.padding_left=12 label.padding_right=12)
  i=0
  while read -r pid etime pcpu comm; do
    [ -n "$pid" ] || continue
    i=$((i + 1))
    args+=(--add item "ai_agents.row.$i" popup.ai_agents
           --set "ai_agents.row.$i" icon=$ICON_AGENTS icon.color=$PURPLE icon.padding_left=10
             background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 width=300
             label="$(printf '%s · up %s · %s%% cpu' "${comm##*/}" "$etime" "$pcpu")"
             label.font="$ROW_FONT" label.padding_right=12
             script="$CONFIG_DIR/plugins/popup_row.sh"
             click_script="kill $pid 2>/dev/null; sketchybar --set ai_agents popup.drawing=off; $CONFIG_DIR/plugins/notify.sh toggles 'Agents' 'Stopped ${comm##*/} (pid $pid)'"
           --subscribe "ai_agents.row.$i" mouse.entered mouse.exited)
  done < <(ps -axo pid=,etime=,%cpu=,comm= | grep -E "$AGENT_RE")
  if [ "$i" = 0 ]; then
    args+=(--add item ai_agents.row.none popup.ai_agents
           --set ai_agents.row.none icon.drawing=off background.drawing=off
             label="nothing running" label.color=$WHITE label.font="$ROW_FONT"
             label.padding_left=12 label.padding_right=12)
  fi
  sketchybar "${args[@]}" 2>/dev/null
  toggle_popup
  exit 0
fi

# ponytail: process-name matching, extend AGENT_RE above for new agents
COUNT=$(ps -axo comm= | grep -cE '(^|/)(claude|codex|gemini)$')

if [ "$COUNT" -gt 0 ]; then
  sketchybar --set "$NAME" drawing=on label="$COUNT"
else
  sketchybar --set "$NAME" drawing=off
fi
