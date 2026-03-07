#!/usr/bin/env bash
# Stop hook: run nix flake check before allowing Claude to stop

set -euo pipefail

if ! command -v nix &>/dev/null; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR}"

if ! nix flake check; then
  printf '\nnix flake check failed — fix the errors before finishing.\n' >&2
  exit 2
fi
