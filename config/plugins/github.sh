#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"
hover
close_popup_on_exit

if [ "$SENDER" = "mouse.clicked" ]; then
  sketchybar --remove '/github.row\..*/' 2>/dev/null
  sketchybar --add item github.row.head popup.github \
    --set github.row.head icon.drawing=off background.drawing=off label="PRs awaiting your review" \
      label.color=$PINK label.font="$HEAD_FONT" label.padding_left=12 label.padding_right=12
  i=0
  gh search prs --review-requested=@me --state=open --limit 5 --json title,url 2>/dev/null \
    | python3 -c "import json,sys; [print(p['url'] + '\t' + (p['title'][:38] + '…' if len(p['title']) > 38 else p['title'])) for p in json.load(sys.stdin)]" \
    | while IFS=$'\t' read -r url title; do
    i=$((i + 1))
    sketchybar --add item "github.row.$i" popup.github \
      --set "github.row.$i" icon=󰊤 icon.color=$CYAN icon.padding_left=10 \
        background.drawing=on background.color=$TRANSPARENT background.corner_radius=6 width=$POP_W_WIDE \
        label="$title" label.font="$ROW_FONT" label.padding_right=12 \
        script="$CONFIG_DIR/plugins/popup_row.sh" \
        click_script="open '$url'; sketchybar --set github popup.drawing=off" \
      --subscribe "github.row.$i" mouse.entered mouse.exited
  done
  toggle_popup
  exit 0
fi

REV=$(gh search prs --review-requested=@me --state=open --limit 30 --json number -q length 2>/dev/null)
MINE=$(gh search prs --author=@me --state=open --limit 30 --json number -q length 2>/dev/null)
[ -z "$REV" ] && { sketchybar --set "$NAME" drawing=off; exit 0; }

COLOR=$WHITE
[ "$REV" -gt 0 ] && COLOR=$ORANGE
sketchybar --set "$NAME" drawing=on label="${REV}·${MINE:-0}" label.color=$COLOR
