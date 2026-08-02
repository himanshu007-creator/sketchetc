#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
source "$CONFIG_DIR/plugins/popup_lib.sh"
source "$CONFIG_DIR/plugins/storage_lib.sh"

# the agents people actually leave running; click a row to stop a runaway one
AGENT_RE='(^|/| )(claude|codex|gemini|cursor-agent|aider|ollama|opencode|amp)$'
SEEN="${TMPDIR:-/tmp}/sketchetc_agents_seen"

hover
close_popup_on_exit

running() { ps -axo pid=,etime=,%cpu=,comm= | grep -E "$AGENT_RE"; }

if [ "$SENDER" = "mouse.clicked" ]; then
  pop_begin ai_agents "$POP_W_WIDE"
  pop_head "Agents"
  i=0
  while read -r pid etime pcpu comm; do
    [ -n "$pid" ] || continue
    i=$((i + 1))
    pop_row "a$i" "$ICON_AGENTS" "$(printf '%s · up %s · %s%% cpu' "${comm##*/}" "$etime" "$pcpu")" \
      "kill $pid 2>/dev/null; sketchybar --set ai_agents popup.drawing=off; $CONFIG_DIR/plugins/notify.sh agents 'Agents' 'Stopped ${comm##*/}'" \
      "$PURPLE"
  done < <(running)
  [ "$i" = 0 ] && pop_row none "$ICON_AGENTS" "nothing running" "" "$WHITE"

  # Today's tokens, read from local transcripts. Tokens only, never a cost: the
  # rates are not in those files, so a dollar figure would be invented.
  read -r TIN TOUT TCACHE < <("$CONFIG_DIR/plugins/agents_usage.sh" 2>/dev/null)
  if [ -n "$TIN" ]; then
    pop_kv tin  󰁝 "in today"    "$TIN"    "$CYAN"
    pop_kv tout 󰁅 "out today"   "$TOUT"   "$PINK"
    pop_kv tcac 󰆼 "cached"      "$TCACHE" "$WHITE"
    n=0
    while IFS=$'\t' read -r tokens proj; do
      [ -n "$proj" ] || continue
      n=$((n + 1))
      pop_kv "p$n" 󰉋 "$(printf '%.11s' "$proj")" "$tokens" "$PURPLE"
    done < <("$CONFIG_DIR/plugins/agents_usage.sh" project 2>/dev/null)
  fi

  # the rules file for the project you were last working in, which is the one
  # you actually keep editing
  RULES=$("$CONFIG_DIR/plugins/agents_rules.sh" path 2>/dev/null)
  [ -n "$RULES" ] && pop_row rules 󰈙 "Open $(basename "$RULES")" \
    "sketchybar --set ai_agents popup.drawing=off; open -t '$RULES'" "$CYAN"

  # only shown when ollama is actually installed
  if command -v ollama >/dev/null 2>&1; then
    MODEL=$(ollama ps 2>/dev/null | awk 'NR==2 {print $1}')
    pop_kv ollama 󰧑 "ollama" "${MODEL:-idle}" "$ORANGE"
  fi

  pop_end
  toggle_popup
  exit 0
fi

# ---- routine tick ----------------------------------------------------------
# Agent runs are long and people walk away from them, so an agent disappearing is
# worth saying out loud. Remembering pids between ticks is what makes "finished"
# distinguishable from "never started".
NOW=$(running | awk '{print $1"|"$4}')
COUNT=$(printf '%s\n' "$NOW" | grep -c . )

if [ -f "$SEEN" ]; then
  while IFS='|' read -r pid comm; do
    [ -n "$pid" ] || continue
    if ! printf '%s\n' "$NOW" | grep -q "^$pid|"; then
      "$CONFIG_DIR/plugins/notify.sh" agents "Agents" "${comm##*/} finished" &
    fi
  done < "$SEEN"
fi
printf '%s\n' "$NOW" > "$SEEN"

if [ "${COUNT:-0}" -gt 0 ]; then
  sketchybar "${ANIM_FAST[@]}" --set "$NAME" drawing=on label="$COUNT"
else
  sketchybar --set "$NAME" drawing=off
fi
