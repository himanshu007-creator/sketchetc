# Release notes

## 1.3.5 — Notifications you can actually control

- Every notification type is now sound, silent or off on its own
- AI agent completion is its own category, on by default, so you can quiet it without losing everything else
- Shelf drops and new release alerts finally appear in Settings

## 1.3.4 — theme studio recolours itself, and opens in the right colours

- Fixed: the Theme Studio opened with a pink background. A change in 1.3.3 shifted its arguments and swapped the background with the accent colour
- Applying a theme now recolours the Theme Studio itself immediately, instead of keeping the old colours until you closed and reopened it
- The studio's arguments are named rather than positional, so a future change cannot silently shift them, and a test now checks that what the app passes is exactly what the window reads

## 1.3.3 — theme and iconset selection applies again

- Fixed: picking a theme or an icon set did nothing. The pickers wrote to a path the bar stopped reading in 1.3.1, and nothing failed loudly enough to notice
- Every preference is now a key in your config, with one declared default for each, and there is a single way to read or write state. A picker and the bar can no longer disagree about where a setting lives
- A theme you edited now wins over the built-in of the same name, instead of being shadowed by it
- Upgrading preserves everything you chose: theme, icon set, notification sound, tray state, fullscreen guard opt-out and widget toggles. Settings that used to live inside the app folder, where a reinstall discarded them, are carried across automatically
- Added scripts/test_config.sh, run before every commit and in CI, covering selection round trips, upgrade preservation and two guards that ban hardcoded config paths

## 1.3.2 — fix upgrading from earlier versions

- Fixed: upgrading from 1.3.0 or earlier could fail. Settings and widget toggles lived inside the checkout, so a release that touched those files made the update refuse to apply, and the one line installer aborted
- Both the installer and the in-app update now move your settings to ~/.config/sketchetc before updating, so your data folder, widget toggles and themes carry across untouched

## 1.3.1 — the bar becomes a drop shelf, and your settings leave the repo

- Drop a file or folder anywhere on the topbar to shelve it, then drag it back off wherever you need it. The shelf holds references, so nothing is duplicated, and it only accepts drops while the shelf widget is enabled
- Fixed: dragging a file off the shelf could delete the original. The shelf offered receiving apps a move operation, and moving destroys the very file a reference points to. It is copy only now
- Fixed: your settings and widget toggles lived inside the git checkout, so reinstalling, re-cloning or installing on a second machine could silently change your data folder and make the journal look lost. They now live in ~/.config/sketchetc, outside anything git manages, and an existing config is migrated across automatically on first launch
- Settings and widgets added in a release now appear for existing users instead of silently never showing up, without overwriting any choice you already made
- Journal search across every entry and personal note, by word, date or filename
- Screen recording, an on-device OCR capture, a colour picker, and a microphone mute toggle
- Agents widget shows what is running, stops a runaway one, tells you when a long run finishes, and reports today's token totals per project read only from local session files
- Popups share one row height, three widths and one header treatment, and all motion runs on one curve that animations=off disables entirely
- Fixed: the shelf window showed one row and needed scrolling for the rest, and could not be dismissed once focus moved

## 1.3.0 — instant popups, menu bar icons, OCR and a prompt library

- Speed: popups open several times faster. The clipboard widget was spending 275ms of osascript every second re-detecting copies the watcher already saw, the palette and settings are now read from a prebuilt cache instead of re-sourced on every event, popups are built in one call instead of one per row, and the aura popup replaced three python3 spawns with a single awk pass
- Menu bar icons from other apps (Docker, Cursor, Dropbox) are mirrored into the bar with a chevron that collapses them into a tray. Needs Screen Recording permission
- Capture area to text: on-device OCR puts the words on your clipboard instead of a picture of them
- Prompt library: plain text files in your data folder, Option+P to pick and paste anywhere
- Clipboard history holds 20 entries instead of 5, and the Option+V picker filters as you type
- Battery popup shows cycle count, health and condition, matching the figures System Settings reports
- Aura no longer goes blank on the first of the month, and the popup shows today, 7 days, 30 days and your streak in a proper column
- The pomodoro pill collapses to its icon when idle instead of holding a wide empty capsule, hover borders no longer collide, and the widgets menu is alphabetical with help pinned last
- Notifications containing quotes or backslashes no longer fail silently

## 1.2.4 — snips land in Option+V, releases noticed within 30 minutes

- Every capture in the shot menu now lands on the clipboard and appears in Option+V immediately, with a Snip ready to paste notification and no voice
- Option+V captures the clipboard as it opens, so the thing you just copied is always in the list even if the background watcher was not running
- One snip no longer creates two entries in clipboard history
- Cancelling an area to clipboard capture with Esc no longer claims it succeeded, and Finder is no longer pulled to the front after every capture
- New releases are noticed within 30 minutes instead of up to six hours, and still notify only once per release
- The clipboard popup now mentions that Option+V opens it in any app

## 1.2.3 — one installer instead of two

- The repo installer and the published installer are now a single implementation. install.sh is a thin wrapper that runs docs/install.sh with a new --local flag, which installs from the checkout instead of cloning
- This removes the drift that let an identical bug be fixed in one installer and left in the other
- CI asserts --local links to the checkout and never clones, and both installer paths run with the counter disabled

## 1.2.2 — installs no longer die on optional setup steps

- Fresh macOS accounts have no ~/Library/Fonts. The app icon font download could not create it, and under set -e that ended the install before the bar ever started, leaving no menu bar at all. Both installers now create the folder and treat a failed download as a warning
- The ctrl+1..4 desktop hotkeys are no longer able to abort an install. If defaults or activateSettings fails you lose the shortcuts, nothing else
- The repo installer used by the git clone route carried the same font bug as the one line installer and is now fixed too
- CI runs both installers for real against a bare HOME instead of only a dry run, which could not execute the steps that kept breaking

## 1.2.1 — top bar badges drawn locally

- The install and visit counters in the site header no longer show "inaccessible" when shields.io is throttled: every badge is drawn from the raw API value in one consistent style
- Each badge carries its own icon rather than sharing one, and unfilled badges stay hidden instead of flashing a placeholder

## 1.2.0 — journal history adoption, update confirmation, signed releases

- Journal: pointing the data folder at a folder that is already a journal root now adopts the history instead of shadowing it with an empty one. Entries are moved under journal/ with their immutability and hash chain intact
- Updates: the Apple menu has a Check for updates row, and nothing installs until you confirm. The dialog shows the version jump and the incoming changes
- Updates: changing any setting used to break every future update, because a locally edited tracked file makes a fast-forward pull refuse. Your edits are now set aside and restored around the pull
- Installer: reinstalling over an existing setup no longer aborts part way through when skhd is already installed
- Helpers: one shared builder compiles anything missing or stale, so a fresh clone, an update and a plain reload all self-heal. This fixes clipboard history, the aura window, the journal entry box and the release popup silently doing nothing
- Clipboard: native Cmd+Shift+4 and Cmd+Shift+5 screenshots reach clipboard history within a second, so Option+V always has your latest shot on top
- Releases are signed with keyless cosign and carry build provenance; verify with cosign verify-blob (see SECURITY.md)
- Licence is now CC BY-NC-ND 4.0: free forever and never sold, no charging and no redistributing a modified copy

## 1.1.0 — self-healing helpers, signed releases, new licence

- Fixed clipboard history, the aura window, the journal entry box and the release popup: their compiled helpers had gone missing and nothing rebuilt them
- Native screenshots (Cmd+Shift+4 and Cmd+Shift+5) now reach clipboard history within a second, so Option+V always has your latest shot at the top
- One shared builder compiles any helper whose binary is missing or stale, so a fresh clone, an update and a plain reload all self-heal
- Release artifacts are signed with keyless cosign: install.sh, a source tarball and SHA256SUMS, verifiable with cosign verify-blob
- Relicensed to CC BY-NC-ND 4.0: free forever and never sold, no charging and no redistributing a modified copy
- Site: the install command no longer clips mid-URL, top bar badges keep a fixed order, and the cursor glow is smaller and dot-free

## 1.0.0 — the first real release

- **Clipboard history** with Option+V picker: last 5 copies, text and image thumbnails, pastes into any app including terminals
- **Theme Studio**: 5 built-in palettes (read only) plus your own, every color role editable with native pickers, 6 global icon sets
- **Window snapping**, quick switches, screenshot menu, Bluetooth devices, audio output switching
- **Aura points**: pomodoros scored on real activity, shareable PNG cards
- **Journal**: tamper-evident daily work log that locks at noon the next day, plus a personal scratchpad
- **Settings window**: silence any notification category, sounds, spoken announcements, screenshot behavior
- Fixed widget widths so ticking numbers never reflow the bar
- One-line installer and in-bar update nudges
