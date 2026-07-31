#!/bin/bash
# One popup system.
#
# Every builder used to hand-roll its rows, which is how we ended up with ten
# different row widths (340, 300, 280, 260, 250, 240, 225, 220, 200, 190) and
# three different header colours across popups that are meant to read as one
# product. These helpers are the whole vocabulary: a header, a row, an aligned
# key/value row, and an empty state.
#
# Usage — accumulate into `args`, then issue ONE sketchybar call. Each call costs
# ~41ms of IPC, so a row-at-a-time popup spent a third of a second before drawing:
#
#   pop_begin clipboard
#   pop_head  "Clipboard"
#   pop_row   entry1 "$ICON_CLIP" "some text" "paste.sh 'x'"
#   pop_empty "nothing copied yet"
#   pop_end

# One motion vocabulary. Six ad-hoc curve/duration pairs were in use (sin 12,
# sin 15, sin 20, tanh 8, tanh 10, tanh 30), which is why nothing felt like it
# belonged to the same product. Two curves now: ANIM for reveals and value
# changes, ANIM_FAST for hover.
#
# With animations=off both arrays are empty, so the same call sites render
# instantly instead of every one of them needing a branch.
if [ "${SETTING_animations:-on}" = "off" ]; then
  ANIM=()
  ANIM_FAST=()
else
  ANIM=(--animate sin 12)
  ANIM_FAST=(--animate tanh 8)
fi

# three widths, not ten: compact for toggles, standard for most, wide for content
POP_W_COMPACT=220
POP_W=280
POP_W_WIDE=340
POP_RADIUS=6
POP_PAD_L=12
POP_PAD_R=12

pop_begin() { # <item>  — start a popup, clearing whatever it held before
  POP_ITEM="$1"
  POP_WIDTH="${2:-$POP_W}"
  args=(--remove "/${POP_ITEM}\.row\..*/")
  POP_N=0
  POP_ROWS=0
}

pop_head() { # <title>
  args+=(--add item "${POP_ITEM}.row.head" "popup.${POP_ITEM}"
         --set "${POP_ITEM}.row.head" icon.drawing=off background.drawing=off
           label="$1" label.color=$PINK label.font="$HEAD_FONT"
           label.padding_left=$POP_PAD_L label.padding_right=$POP_PAD_R)
}

# A plain row. Passing a click script makes it interactive: hover highlight and
# pointer feedback come with it, so an actionable row always looks actionable and
# a static one never pretends to be.
pop_row() { # <name> <icon> <label> [click_script] [icon_colour]
  POP_N=$((POP_N + 1)); POP_ROWS=$((POP_ROWS + 1))
  local n="${POP_ITEM}.row.$1" ico="$2" label="$3" click="$4" col="${5:-$CYAN}"
  args+=(--add item "$n" "popup.${POP_ITEM}"
         --set "$n" icon="$ico" icon.color="$col" icon.padding_left=$POP_PAD_L icon.padding_right=8
           label="$label" label.font="$ROW_FONT" label.padding_right=$POP_PAD_R
           width=$POP_WIDTH)
  if [ -n "$click" ]; then
    args+=(--set "$n" background.drawing=on background.color=$TRANSPARENT
             background.corner_radius=$POP_RADIUS
             script="$CONFIG_DIR/plugins/popup_row.sh"
             click_script="$click"
           --subscribe "$n" mouse.entered mouse.exited)
  else
    args+=(--set "$n" background.drawing=off)
  fi
}

# Key on the left, value right-aligned. A popup item *is* a row, so the column
# comes from the text: the row font is monospace, so printf padding lines up.
pop_kv() { # <name> <icon> <key> <value> [icon_colour]
  pop_row "$1" "$2" "$(printf '%-13s %8s' "$3" "$4")" "" "${5:-$CYAN}"
}

pop_empty() { # <text> — only draws when nothing else did
  [ "$POP_ROWS" -gt 0 ] && return 0
  POP_N=$((POP_N + 1))
  args+=(--add item "${POP_ITEM}.row.empty" "popup.${POP_ITEM}"
         --set "${POP_ITEM}.row.empty" icon.drawing=off background.drawing=off
           label="$1" label.color=$PURPLE label.font="$ROW_FONT"
           label.padding_left=$POP_PAD_L label.padding_right=$POP_PAD_R
           width=$POP_WIDTH)
}

# A quieter row for hints and shortcuts, so guidance never competes with content
pop_hint() { # <text>
  args+=(--add item "${POP_ITEM}.row.zz_hint" "popup.${POP_ITEM}"
         --set "${POP_ITEM}.row.zz_hint" icon.drawing=off background.drawing=off
           label="$1" label.color=$PURPLE label.font="$ROW_FONT"
           label.padding_left=$POP_PAD_L label.padding_right=$POP_PAD_R)
}

pop_end() { sketchybar "${args[@]}" 2>/dev/null; }
