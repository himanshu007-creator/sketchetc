# Release notes

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
