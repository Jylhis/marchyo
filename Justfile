# Run all checks (lint + eval)
check:
    nix flake check --no-build
    statix check .
    deadnix --fail --exclude .devenv result .

# Format all nix files
fmt:
    nix fmt

# Build the reference NixOS configuration
build:
    nix build .#nixosConfigurations.default.config.system.build.toplevel

# Update all inputs: flake.lock -> devenv.lock
update:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake update
    REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
    echo "Syncing devenv to nixpkgs $REV"
    sed -i "s|url: github:NixOS/nixpkgs/.*|url: github:NixOS/nixpkgs/$REV|" devenv.yaml
    devenv update
    echo "Done. All locks pinned to $REV"

# Verify flake.lock and devenv.lock reference the same nixpkgs rev
verify:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking nixpkgs rev sync..."
    FLAKE_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
    DEVENV_REV=$(jq -r '.nodes.nixpkgs.locked.rev' devenv.lock)
    if [ "$FLAKE_REV" != "$DEVENV_REV" ]; then
        echo "FAIL: nixpkgs revs diverged"
        echo "  flake:  $FLAKE_REV"
        echo "  devenv: $DEVENV_REV"
        exit 1
    fi
    echo "OK: all locks pinned to $FLAKE_REV"

# Run the default configuration VM (x86_64-linux only)
run:
    nix run

# Alias for run
vm: run
