# Marchyo development commands
# Run `just` to see available recipes

system := `nix eval --impure --expr builtins.currentSystem 2>/dev/null || echo '"x86_64-linux"'`

# Show available recipes
default:
    @just --list

# Format all files (nixfmt, deadnix, statix, shellcheck, yamlfmt)
fmt:
    treefmt

# Format check (CI mode, no writes)
fmt-check:
    treefmt --ci

# Run all evaluation tests
check:
    nix-build -A checks.x86_64-linux

# Alias for check
test: check

# Build the reference NixOS configuration
build:
    nix-build -A nixosConfigurations.default.config.system.build.toplevel

# Run the QEMU VM with all features enabled
run:
    nix run

# Display flake outputs
show:
    nix flake show

# List available checks
list-checks:
    nix eval .#checks.x86_64-linux --apply builtins.attrNames

# Update all npins sources
update:
    npins update

# Update a specific npins source
update-pin name:
    npins update {{ name }}

# Show npins status
pins:
    npins show

# Update flake.lock (for consumer compatibility)
update-flake:
    nix flake update
