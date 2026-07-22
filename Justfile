# List all available recipes
default:
    @just --list

# Run all checks (lint + eval)
check:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname)" == "Darwin" ]]; then
      # nix flake check deeply evaluates all nixosConfigurations, which
      # requires Linux builders unavailable on macOS. Evaluate only the
      # outputs that are buildable on the current platform.
      echo "darwin: evaluating module exports..."
      nix eval .#nixosModules  --apply builtins.attrNames > /dev/null
      nix eval .#darwinModules --apply builtins.attrNames > /dev/null
      nix eval .#homeManagerModules --apply builtins.attrNames > /dev/null
      echo "darwin: evaluating darwin configurations..."
      for cfg in $(nix eval .#darwinConfigurations --apply builtins.attrNames --json | nix run nixpkgs#jq -- -r '.[]'); do
        nix eval ".#darwinConfigurations.$cfg.config.system.build.toplevel" --apply '(_: "ok")' > /dev/null
        echo "  ok: darwinConfigurations.$cfg"
      done
      echo "darwin: checking formatter..."
      nix build --dry-run .#formatter."$(nix eval --impure --raw --expr builtins.currentSystem)" 2>/dev/null
    else
      nix flake check --no-build
    fi
    statix check .
    deadnix --fail --exclude .devenv result .

# Format all nix files
fmt:
    nix fmt

# Build NixOS configuration (config: x86_64, aarch64)
build-nixos config="x86_64":
    nix build .#nixosConfigurations.{{config}}.config.system.build.toplevel

# Build Darwin configuration (config: aarch64, x86_64)
build-darwin config="aarch64":
    nix build .#darwinConfigurations.{{config}}.config.system.build.toplevel

# Build Home Manager configuration (config: x86_64-linux, aarch64-linux, aarch64-darwin, x86_64-darwin)
build-home config="x86_64-linux":
    nix build .#homeConfigurations.{{config}}.activationPackage

# Build nix-on-droid configuration (config: aarch64). --impure is required:
# nix-on-droid uses builtins.storePath, disallowed in pure flake eval.
build-nix-on-droid config="aarch64":
    nix build --impure .#nixOnDroidConfigurations.{{config}}.activationPackage

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

# Typecheck and unit-test the marchyo CLI
cli-test:
    cd packages/marchyo-cli && bun install --frozen-lockfile && bun run typecheck && bun test

# Re-pin the marchyo-cli node_modules FOD hash after bun.lock changes
cli-repin:
    #!/usr/bin/env bash
    set -euo pipefail
    pkg=packages/marchyo-cli/package.nix
    current=$(grep -oE 'outputHash = "sha256-[^"]+"' "$pkg" | cut -d'"' -f2)
    echo "Current hash: $current"
    fake="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    sed -i "s|outputHash = \"${current}\"|outputHash = \"${fake}\"|" "$pkg"
    got=$(nix build .#legacyPackages.x86_64-linux.marchyo-cli 2>&1 | grep -oE 'got: +sha256-[A-Za-z0-9+/=]+' | grep -oE 'sha256-[A-Za-z0-9+/=]+' | head -1) || true
    if [ -z "${got:-}" ]; then
        echo "No hash mismatch reported; restoring previous hash."
        sed -i "s|outputHash = \"${fake}\"|outputHash = \"${current}\"|" "$pkg"
        exit 0
    fi
    echo "Pinning new hash: $got"
    sed -i "s|outputHash = \"${fake}\"|outputHash = \"${got}\"|" "$pkg"
    nix build .#legacyPackages.x86_64-linux.marchyo-cli
    echo "Done. $pkg pinned to $got"

# Run the website dev server (landing + docs)
site-dev:
    cd site && bun install && bun run dev

# Build the website (landing + docs)
site-build:
    cd site && bun install --frozen-lockfile && bun run check && bun run build
