# Run all checks (lint + eval)
check:
    nix flake check --no-build
    statix check .
    deadnix --fail --exclude npins .devenv result .

# Format all nix files
fmt:
    nix fmt

# Build the reference NixOS configuration
build:
    nix build .#nixosConfigurations.default.config.system.build.toplevel

# Update all pins in sync: npins -> devenv.lock -> flake.lock
update:
    #!/usr/bin/env bash
    set -euo pipefail
    npins update
    REV=$(jq -r '.pins.nixpkgs.revision' npins/sources.json)
    echo "Syncing all locks to nixpkgs $REV"
    printf 'inputs:\n  nixpkgs:\n    url: github:NixOS/nixpkgs/%s\n' "$REV" > devenv.yaml
    devenv update
    nix flake lock --override-input nixpkgs "github:NixOS/nixpkgs/$REV"
    echo "Done. All locks pinned to $REV"

# Verify all lock files reference the same nixpkgs rev
verify:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking nixpkgs rev sync..."
    NPINS_REV=$(jq -r '.pins.nixpkgs.revision' npins/sources.json)
    FLAKE_REV=$(jq -r '.nodes.nixpkgs.locked.rev' flake.lock)
    DEVENV_REV=$(jq -r '.nodes.nixpkgs.locked.rev' devenv.lock)
    if [ "$NPINS_REV" != "$FLAKE_REV" ] || [ "$NPINS_REV" != "$DEVENV_REV" ]; then
        echo "FAIL: nixpkgs revs diverged"
        echo "  npins:  $NPINS_REV"
        echo "  flake:  $FLAKE_REV"
        echo "  devenv: $DEVENV_REV"
        exit 1
    fi
    echo "OK: all locks pinned to $NPINS_REV"

# Run VM (x86_64-linux only)
vm:
    nix run
