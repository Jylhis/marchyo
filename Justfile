# List all available recipes
default:
    @just --list

# Run all checks (lint + eval)
check:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake check --no-build
    statix check .
    deadnix --fail --exclude .dev result .

# Run every check, building the heavy ones too (Hyprland --verify-config, theme assets, Plymouth, ISO evals)
check-full:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake check
    system=$(nix eval --raw --impure --expr builtins.currentSystem)
    heavy=".#legacyPackages.$system.heavyChecks"
    mapfile -t names < <(nix eval --raw "$heavy" --apply 'c: builtins.concatStringsSep "\n" (builtins.attrNames c)')
    nix build --no-link -L "${names[@]/#/$heavy.}"

# Format all nix files
fmt:
    nix fmt

# Build NixOS configuration (config: x86_64, aarch64)
build-nixos config="x86_64":
    nix build .#nixosConfigurations.{{config}}.config.system.build.toplevel

# Build an installer ISO (variant: minimal, graphical; x86_64-linux)
iso variant="minimal":
    nix build .#iso-{{variant}}

# Update all flake inputs
update:
    nix flake update

# Run the default configuration VM (x86_64-linux only)
run:
    nix run

# Alias for run
vm: run

# Generate a CycloneDX/SPDX SBOM of the reference NixOS system (sbomnix)
sbom:
    nix run .#sbom

# Scan the reference system closure for known CVEs (vulnxscan + vulnix; needs network)
vuln-scan:
    nix run .#vuln-scan

# Boot the reference system in a VM and run host-hardening + vuln scanners (lynis, vuls)
security-vm:
    nix build .#security-vm-test -L

# Full local security sweep: SBOM + closure CVE scan + VM hardening audit
security-scan: sbom vuln-scan security-vm

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
