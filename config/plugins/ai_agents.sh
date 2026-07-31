#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
source "$CONFIG_DIR/plugins/popup_lib.sh"

# the agents people actually leave running; click a row to stop a runaway one
AGENT_RE='(^|/| )(claude|codex|gemini|cursor-agent|aider|ollama|opencode|amp)$'
hover
close_popup_on_exit

if [ "$SENDER" = "mouse.clicked" ]; then
  pop_begin ai_agents "$POP_W_WIDE"
  pop_head "Running agents"
  i=0
  while read -r pid etime pcpu comm; do
    [ -n "$pid" ] || continue
    i=$((i + 1))
    pop_row "a$i" "$ICON_AGENTS" "$(printf '%s · up %s · %s%% cpu' "${comm##*/}" "$etime" "$pcpu")" \
      "kill $pid 2>/dev/null; sketchybar --set ai_agents popup.drawing=off; $CONFIG_DIR/plugins/notify.sh toggles 'Agents' 'Stopped ${comm##*/}'" \
      "$PURPLE"
  done < <(ps -axo pid=,etime=,%cpu=,comm= | grep -E "$AGENT_RE")
  pop_empty "nothing running"
  pop_end
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
