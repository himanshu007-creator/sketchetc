# Writing a widget

Every widget is two small bash files plus one line of wiring. The palette and
helpers come from the framework — you never hardcode colors.

## Anatomy

```
config/
├── items/mywidget.sh      # creation: what it looks like, what events it hears
├── plugins/mywidget.sh    # logic: runs on every event with $NAME and $SENDER
└── widgets.conf           # mywidget=on   ← makes it toggleable from the 󰀵 menu
```

## 1. `items/mywidget.sh`

```bash
#!/bin/bash
widget_on mywidget || return 0        # respect the toggle
sketchybar --add item mywidget right \
  --set mywidget \
    update_freq=10 \
    icon=󰀄 \
    icon.color=$CYAN \
    script="$PLUGIN_DIR/mywidget.sh" \
  --subscribe mywidget mouse.entered mouse.exited mouse.clicked
```

Add `$POPUP_PROPS popup.align=right` and subscribe `mouse.entered.global
mouse.exited.global` if the widget has a popup.

## 2. `plugins/mywidget.sh`

```bash
#!/bin/bash
source "$CONFIG_DIR/plugins/hover.sh"   # loads theme palette + helpers
hover                                    # animated hover glow (exits on hover events)
close_popup_on_exit                      # popup hygiene (if you have a popup)

if [ "$SENDER" = "mouse.clicked" ]; then
  # rebuild popup rows, then:
  toggle_popup                           # exclusive open/close with bounce
  exit 0
fi

# routine tick:
sketchybar --set "$NAME" label="$(date +%S)s"
```

## 3. Wire it

- Add `source "$ITEM_DIR/mywidget.sh"` to `sketchybarrc` (order = position).
- Add `mywidget=on` to `widgets.conf`.
- Add `mywidget` to the WIDGETS loop in `items/apple.sh` and to the popup list
  in `plugins/click_watch.sh` if it has a popup.

## Rules of the road

- **Colors**: only `$PINK $CYAN $ORANGE $RED $PURPLE $WHITE $ITEM_BG_COLOR` —
  these come from the active theme, so your widget works in all of them.
  (`PINK`/`CYAN` are role names: accent-1 / accent-2.)
- **Popup rows**: `background.drawing=off`, fonts `$ROW_FONT` / `$HEAD_FONT`,
  hoverable rows use `plugins/popup_row.sh`.
- **No background processes** — children spawned from plugins get reaped.
  Poll from your routine tick, or detach via
  `osascript -e 'do shell script "nohup cmd &"'` if you truly must.
- **State** goes in `${TMPDIR:-/tmp}/sketchybar_<name>` files.
- **Hide, don't error**: if your data source is missing, `--set $NAME drawing=off`.

## extras

Mirrors third-party menu bar icons via sketchybar's `alias` component.
`items/extras.sh` enumerates `sketchybar --query default_menu_items`, skips the
ones macOS already gives us, and creates an alias per remaining item.
`plugins/extras.sh` toggles them as a group. Requires Screen Recording.
Deny specific owners with `extras_deny=Owner1,Owner2` in `settings.conf`.
