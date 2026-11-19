#!/usr/bin/env bash
# Regenerates CHANGELOG.md from .changes/. Run from the repository root.
# The unreleased fragments form the open month, named after the newest fragment.
set -euo pipefail

args=()
if ls .changes/unreleased/*.yaml >/dev/null 2>&1; then
  month=$(sed -n 's/^time: \([0-9]\{4\}-[0-9]\{2\}\).*/\1/p' .changes/unreleased/*.yaml | sort | tail -n 1)
  args=(--include-unreleased "## $month")
fi

changie merge "${args[@]}"

sed 's/\([^[:space:]]\)\(## [0-9]\{4\}-[0-9][0-9]\)$/\1\n\2/' CHANGELOG.md |
  awk '/^## / && NR > 1 && prev != "" { print "" } { print; prev = $0 }' >CHANGELOG.md.tmp
mv CHANGELOG.md.tmp CHANGELOG.md
