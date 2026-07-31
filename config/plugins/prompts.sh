#!/bin/bash
# Prompt library · Option+P anywhere.
#
# Reusing a prompt is the single most repeated action for anyone working with an
# LLM, technical or not, and today that means digging through a notes app. These
# are plain .txt files in your data folder: editable in any editor, synced by
# whatever you already sync with, no account and nothing leaving the machine.
#
#   prompts.sh          pick one and paste it
#   prompts.sh add      save whatever is on the clipboard as a new prompt
#   prompts.sh open     open the folder
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
export CONFIG_DIR
source "$CONFIG_DIR/plugins/storage_lib.sh"

DIR="$(data_dir)/prompts"
mkdir -p "$DIR" 2>/dev/null

seed() { # a library with nothing in it teaches nobody what it is for
  [ -n "$(ls -A "$DIR" 2>/dev/null)" ] && return
  printf '%s' 'Explain this like I am new to the topic. Be concrete, use one example, and skip the preamble.' > "$DIR/explain simply.txt"
  printf '%s' 'Review this for correctness first, then clarity. Point out what is actually wrong before what is merely different from how you would write it.' > "$DIR/code review.txt"
  printf '%s' 'Rewrite this to be clearer and shorter without losing meaning. Keep my voice. Do not add adjectives.' > "$DIR/tighten this.txt"
  printf '%s' 'Summarise the key points as bullets, then state what decision this implies and what is still unknown.' > "$DIR/summarise.txt"
}

case "${1:-pick}" in
  add)
    TEXT=$(pbpaste 2>/dev/null)
    [ -z "$TEXT" ] && { "$CONFIG_DIR/plugins/notify.sh" clipboard "Prompts" "Nothing on the clipboard to save"; exit 0; }
    # name it from the first few words, which is what you will scan for later
    NAME=$(printf '%s' "$TEXT" | head -1 | tr -cd '[:alnum:] ._-' | cut -c1-40)
    [ -z "$NAME" ] && NAME="prompt $(date +%H%M%S)"
    printf '%s' "$TEXT" > "$DIR/$NAME.txt"
    "$CONFIG_DIR/plugins/notify.sh" clipboard "Prompts" "Saved \"$NAME\""
    ;;
  open)
    open "$DIR"
    ;;
  *)
    seed
    FILES=()
    while IFS= read -r f; do [ -n "$f" ] && FILES+=("$DIR/$f"); done < <(ls -t "$DIR" 2>/dev/null | grep '\.txt$')
    [ "${#FILES[@]}" -eq 0 ] && { "$CONFIG_DIR/plugins/notify.sh" clipboard "Prompts" "No prompts yet · copy some text and use Prompts → Save"; exit 0; }
    PICK=$("$CONFIG_DIR/plugins/bin/clip_picker" --title "Prompts" "${FILES[@]}") || exit 0
    [ -n "$PICK" ] && exec "$CONFIG_DIR/plugins/clipboard_row.sh" paste "$PICK"
    ;;
esac
