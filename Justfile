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

# Update all inputs: flake.lock -> devenv.yaml + devenv.lock
update:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake update
    INPUTS=$(awk '/^inputs:$/{f=1;next} f && /^[^ ]/{f=0} f && /^  [A-Za-z0-9_-]+:$/{gsub(/[ :]/,""); print}' devenv.yaml)
    for name in $INPUTS; do
        REV=$(jq -er --arg n "$name" '.nodes[$n].locked.rev' flake.lock) || {
            echo "FAIL: devenv input '$name' missing from flake.lock"; exit 1; }
        echo "Pinning $name -> $REV"
        sed -i.bak -E "/^  ${name}:$/,/^  [A-Za-z0-9_-]+:$|^[^ ]/ {
            s|^(    url: github:[^/]+/[^/[:space:]]+)(/[0-9a-f]+)?[[:space:]]*$|\1/${REV}|
        }" devenv.yaml
        rm -f devenv.yaml.bak
    done
    devenv update
    echo "Done. All devenv inputs pinned from flake.lock."

# Verify flake.lock and devenv.lock reference the same rev for every shared input
verify:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking shared input rev sync..."
    INPUTS=$(awk '/^inputs:$/{f=1;next} f && /^[^ ]/{f=0} f && /^  [A-Za-z0-9_-]+:$/{gsub(/[ :]/,""); print}' devenv.yaml)
    fail=0
    for name in $INPUTS; do
        FLAKE_REV=$(jq -er --arg n "$name" '.nodes[$n].locked.rev' flake.lock) \
            || { echo "FAIL: $name missing from flake.lock"; fail=1; continue; }
        DEVENV_REV=$(jq -er --arg n "$name" '.nodes[$n].locked.rev' devenv.lock) \
            || { echo "FAIL: $name missing from devenv.lock"; fail=1; continue; }
        if [ "$FLAKE_REV" != "$DEVENV_REV" ]; then
            echo "FAIL: $name diverged"
            echo "  flake:  $FLAKE_REV"
            echo "  devenv: $DEVENV_REV"
            fail=1
        else
            echo "OK: $name @ $FLAKE_REV"
        fi
    done
    [ "$fail" = 0 ] || exit 1
    echo "All shared inputs in sync."

# Run the default configuration VM (x86_64-linux only)
run:
    nix run

# Alias for run
vm: run
