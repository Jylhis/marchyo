#!/usr/bin/env bash
# PostToolUse hook: auto-format .nix files after Edit or Write

set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

if [[ -z "$file_path" ]]; then
  exit 0
fi

if [[ "$file_path" != *.nix ]]; then
  exit 0
fi

if ! command -v nixfmt &>/dev/null; then
  exit 0
fi

nixfmt "$file_path"
