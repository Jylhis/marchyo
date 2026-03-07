#!/usr/bin/env bash
# PreToolUse hook: block edits to generated/lock files

set -euo pipefail

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

if [[ -z "$file_path" ]]; then
  exit 0
fi

# Normalize path for matching
rel_path="${file_path#"${CLAUDE_PROJECT_DIR}"/}"

case "$rel_path" in
  flake.lock)
    # shellcheck disable=SC2016
    printf 'Blocked: flake.lock is a generated file. Update it with `nix flake update` instead.\n' >&2
    exit 2
    ;;
  result | result/*)
    printf 'Blocked: result/ is a Nix build output symlink, not editable source.\n' >&2
    exit 2
    ;;
esac
