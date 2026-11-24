#!/usr/bin/env bash
# PostToolUse hook: format the edited file with the project's treefmt
# (nixfmt, shfmt, yamlfmt, qmlformat, ...). Files no formatter matches are
# left alone. Never blocks an edit: formatter errors go to stderr only.

set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

if [[ -z "$file_path" || ! -f "$file_path" ]]; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}"

if command -v treefmt &>/dev/null; then
  treefmt "$file_path" >&2 || true
elif command -v nix &>/dev/null; then
  nix fmt -- "$file_path" >&2 || true
fi
