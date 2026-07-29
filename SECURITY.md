# Security

## Reporting
Open a [private security advisory](https://github.com/himanshu007-creator/sketchetc/security/advisories/new),
or a normal issue if it is not sensitive.

## What this project does to your machine
Everything is plain, readable shell and Swift — no obfuscation, no minified blobs,
no binaries in the repo (the Swift helpers are compiled locally on your machine).

The installer:
- installs Homebrew packages (sketchybar, fonts, macmon, pngpaste, skhd, switchaudio-osx, blueutil, cliclick)
- clones this repo into `~/.local/share/sketchetc/app` and symlinks `config/` to `~/.config/sketchybar`
- compiles the Swift helpers with `swiftc`
- enables the macOS "Switch to Desktop 1-4" shortcuts and starts the sketchybar service
- pings a public install counter once (skip with `--no-count` or `SKETCHETC_NO_TELEMETRY=1`)

It never asks for `sudo`. The only privileged action in the whole project is the
optional RAM reclaim, which asks macOS for an admin password itself when you press it.

## Verify before you run
```bash
curl -fsSLO https://himanshu007-creator.github.io/sketchetc/install.sh
shasum -a 256 install.sh                     # compare with install.sh.sha256
curl -fsSL https://himanshu007-creator.github.io/sketchetc/install.sh.sha256
less install.sh
bash install.sh
```
Pin to a tag for an immutable install:
`https://raw.githubusercontent.com/himanshu007-creator/sketchetc/v1.0.0/docs/install.sh`

## Data and privacy
No accounts, no analytics, no network calls at runtime except the widgets you
enable (weather, GitHub PRs, update check) and the one-time install counter.
Your journal, aura history and clipboard history stay in the local folder you choose.

## Verifying a release

Every tag gets `install.sh`, a source tarball and `SHA256SUMS` attached, each
signed with keyless [cosign](https://docs.sigstore.dev/). No key to trust: the
signature is tied to this repository's release workflow.

```bash
TAG=v1.1.0
gh release download "$TAG" -R himanshu007-creator/sketchetc
shasum -a 256 -c SHA256SUMS
cosign verify-blob install.sh \
  --bundle install.sh.sigstore.json \
  --certificate-identity-regexp '^https://github.com/himanshu007-creator/sketchetc/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```
