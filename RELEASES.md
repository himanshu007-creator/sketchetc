# Release notes

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
