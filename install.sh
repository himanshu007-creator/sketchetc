#!/bin/bash
# Installs sketchetc from THIS checkout, so ~/.config/sketchybar points at the
# working copy you are sitting in rather than a fresh clone. Useful for the
# git clone route in the README, and for developing on the config.
#
# There is deliberately no logic here. docs/install.sh is the one installer;
# this file only picks its --local mode. Keeping two full implementations is
# what let an identical bug ship in one of them and not the other.
#
# Any flag it takes works here too, e.g. --dry-run, --no-count.
exec "$(cd "$(dirname "$0")" && pwd)/docs/install.sh" --local "$@"
