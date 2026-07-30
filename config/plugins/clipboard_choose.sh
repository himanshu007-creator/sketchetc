#!/bin/bash
# Option+V: centered clipboard picker (arrow keys + Enter, click, Esc; image previews)
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
# clip_lib exports STORE and capture(); sourcing it also pulls in storage_lib
source "$CONFIG_DIR/plugins/clip_lib.sh"

# Capture before listing. Reading the store straight away means anything copied a
# moment ago, or copied while clip_watch was not running, is missing from the picker
# and the newest thing you copied is exactly what you came here to paste.
capture

FILES=()
while read -r f; do FILES+=("$STORE/$f"); done < <(ls -t "$STORE" 2>/dev/null | grep -v '^\.' | head -5)

[ "${#FILES[@]}" -eq 0 ] && { "$CONFIG_DIR/plugins/notify.sh" clipboard "Clipboard" "Nothing copied yet"; exit 0; }

PICK=$("$CONFIG_DIR/plugins/bin/clip_picker" "${FILES[@]}") || exit 0
[ -n "$PICK" ] && exec "$CONFIG_DIR/plugins/clipboard_row.sh" paste "$PICK"
