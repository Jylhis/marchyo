# List all available recipes
default:
    @just --list

# Run all checks (lint + eval)
[group('check')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake check --no-build
    statix check .
    deadnix --fail --exclude .dev result .

# Run every check, building the heavy ones too (Hyprland --verify-config, theme assets, Plymouth, ISO evals)
[group('check')]
check-full:
    #!/usr/bin/env bash
    set -euo pipefail
    nix flake check
    system=$(nix eval --raw --impure --expr builtins.currentSystem)
    heavy=".#legacyPackages.$system.heavyChecks"
    mapfile -t names < <(nix eval --raw "$heavy" --apply 'c: builtins.concatStringsSep "\n" (builtins.attrNames c)')
    nix build --no-link -L "${names[@]/#/$heavy.}"

# Format the whole tree (treefmt)
[group('format')]
fmt:
    nix fmt

# Build NixOS configuration (config: x86_64, aarch64)
[group('build')]
build-nixos config="x86_64":
    nix build .#nixosConfigurations.{{config}}.config.system.build.toplevel

# Build an installer ISO (variant: minimal, graphical; x86_64-linux)
[group('build')]
iso variant="minimal":
    nix build .#iso-{{variant}}

# Update all flake inputs
[group('setup')]
update:
    nix flake update

# Run the default configuration VM (x86_64-linux only)
[group('build')]
run:
    nix run

# Alias for run
[group('build')]
vm: run

# Generate a CycloneDX/SPDX SBOM of the reference NixOS system (sbomnix)
[group('security')]
sbom:
    nix run .#sbom

# Scan the reference system closure for known CVEs (vulnxscan + vulnix; needs network)
[group('security')]
vuln-scan:
    nix run .#vuln-scan

# Boot the reference system in a VM and run host-hardening + vuln scanners (lynis, vuls)
[group('security')]
security-vm:
    nix build .#security-vm-test -L

# Full local security sweep: SBOM + closure CVE scan + VM hardening audit
[group('security')]
security-scan: sbom vuln-scan security-vm

# Typecheck and unit-test the marchyo CLI
[group('cli')]
cli-test:
    cd packages/marchyo-cli && bun install --frozen-lockfile && bun run typecheck && bun test

# Re-pin the marchyo-cli node_modules FOD hash after bun.lock changes
[group('cli')]
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
[group('site')]
site-dev:
    cd site && npm install && npm run dev

# Build the website (landing + docs)
[group('site')]
site-build:
    cd site && npm ci && npm run check && npm run build

# Point this clone's git at the mergiraf merge driver (.gitattributes uses it)
[group('setup')]
init:
    git config merge.mergiraf.name mergiraf
    git config merge.mergiraf.driver 'mergiraf merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L'

# Write a changelog fragment for the current change (interactive)
[group('changelog')]
change:
    changie new

# Regenerate CHANGELOG.md from .changes/
[group('changelog')]
changelog:
    .changes/merge.sh

# Lint commit subjects (convco), reject AI Co-Authored-By trailers, warn on a missing Assisted-by
[group('check')]
commit-lint range='origin/main..HEAD':
    #!/usr/bin/env bash
    set -euo pipefail
    status=0
    convco check '{{ range }}' || status=1
    ai='claude|copilot|codex|gpt|gemini|anthropic'
    bad=$(git log --format='%h %s' -i -E --grep="^co-authored-by:.*($ai)" '{{ range }}')
    if [ -n "$bad" ]; then
        printf 'Co-Authored-By names an AI (use an Assisted-by trailer):\n%s\n' "$bad" >&2
        status=1
    fi
    for c in $(git rev-list --no-merges '{{ range }}'); do
        git show -s --format=%B "$c" | grep -qi '^assisted-by:' ||
            echo "warning: $(git log -1 --format='%h %s' "$c") has no Assisted-by trailer" >&2
    done
    exit "$status"
