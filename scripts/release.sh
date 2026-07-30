#!/bin/bash
# release.sh <patch|minor|major> "headline" ["bullet" "bullet" ...]
# Run on develop. Bumps VERSION, writes release notes, merges into production,
# tags, pushes both branches, and creates the GitHub release.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

LEVEL="${1:-patch}"; HEADLINE="${2:-}"; shift 2 2>/dev/null || true
[ -n "$HEADLINE" ] || { echo "usage: release.sh <patch|minor|major> \"headline\" [bullets...]"; exit 1; }

BR=$(git rev-parse --abbrev-ref HEAD)
[ "$BR" = "develop" ] || { echo "release from develop (you are on $BR)"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree is dirty"; exit 1; }

OLD=$(cat VERSION)
IFS=. read -r MA MI PA <<< "$OLD"
case "$LEVEL" in
  major) MA=$((MA+1)); MI=0; PA=0 ;;
  minor) MI=$((MI+1)); PA=0 ;;
  patch) PA=$((PA+1)) ;;
  *) echo "level must be patch|minor|major"; exit 1 ;;
esac
NEW="$MA.$MI.$PA"

echo "$NEW" > VERSION

# prepend the new section to RELEASES.md
TMP=$(mktemp)
{
  echo "# Release notes"
  echo
  echo "## $NEW — $HEADLINE"
  echo
  if [ "$#" -gt 0 ]; then
    for b in "$@"; do echo "- $b"; done
  else
    # no bullets given: use the commit subjects since the last release
    git log --pretty='- %s' "v$OLD..HEAD" 2>/dev/null | grep -v '^- Merge' || echo "- housekeeping"
  fi
  echo
  tail -n +2 RELEASES.md | sed '1{/^$/d;}'
} > "$TMP"
mv "$TMP" RELEASES.md

./scripts/gen_site_data.sh >/dev/null
./scripts/sync_trust.sh >/dev/null
git add VERSION RELEASES.md docs/data/site.json docs/data/trust.json docs/install.sh.sha256 README.md docs/index.html
git commit -q -m "Release v$NEW: $HEADLINE"
git push -q origin develop

git checkout -q production
git merge -q --no-ff develop -m "Release v$NEW: $HEADLINE"
git tag -a "v$NEW" -m "v$NEW — $HEADLINE"
git push -q origin production --tags
git checkout -q develop

if command -v gh >/dev/null; then
  NOTES=$(awk '/^## /{c++} c==1' RELEASES.md | tail -n +2)
  gh release create "v$NEW" --title "v$NEW — $HEADLINE" --notes "$NOTES" >/dev/null && echo "GitHub release created"
fi

echo "released v$OLD → v$NEW · users see the 󰚰 pill within 6 hours (or on their next reload)"
