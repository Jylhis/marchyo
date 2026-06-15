---
name: marchyo-config
description: Marchyo NixOS/Home Manager module development specialist. Use when creating, modifying, or debugging modules in the Marchyo flake — including options, tests, and integration patterns.
---

# Marchyo Configuration Skill

Specialist knowledge for the Marchyo modular NixOS configuration flake.
See `CLAUDE.md` in the repository root for the authoritative reference.

## Repository Layout

```
modules/nixos/                # NixOS system-level modules (auto-discovered)
modules/home/                 # Home Manager user-level modules (auto-discovered)
modules/generic/              # Shared modules (fontconfig, git, shell, packages, theme)
modules/nixos/options/        # marchyo.* option declarations split by namespace (auto-discovered)
modules/nixos/default.nix     # NixOS module entry — uses lib/discover-modules.nix
modules/home/default.nix      # Home Manager module entry — uses lib/discover-modules.nix
lib/systems.nix               # Single source of truth for the system list
lib/discover-modules.nix      # Auto-import helper for module directories
tests/eval/*.nix              # Evaluation tests, one file per feature (auto-discovered)
tests/lib.nix                 # Shared test helpers (testNixOS, withTestUser)
```

## Key Commands

```bash
nix flake check     # Validate and run all tests (REQUIRED before committing)
nix fmt             # Format all Nix code (REQUIRED before committing)
nix develop         # Enter development shell
nix flake show      # Inspect all flake outputs
nix eval .#checks.x86_64-linux --apply builtins.attrNames  # List tests
```

## Adding a New Module

1. Create the file in `modules/nixos/`, `modules/home/`, or `modules/generic/` — auto-discovery picks it up (no import edit for nixos/home; darwin requires a manual edit)
2. Define any new options under `modules/nixos/options/` — auto-discovered (one file per namespace)
3. Add an evaluation test under `tests/eval/<feature>.nix` — auto-discovered

### Standard NixOS module

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.feature.enable {
    # configuration here
  };
}
```

### Home Manager module accessing NixOS config

```nix
{ config, lib, osConfig ? {}, ... }:
let
  cfg = osConfig.marchyo or {};
in
{ ... }
```

## Defining Options

Options go under `modules/nixos/options/` — pick the namespace file or create one.
Each file declares `options.marchyo.<namespace>`. Every option needs a
`description`; use `lib.mkEnableOption` for boolean flags and `lib.mkDefault` for
overridable values.

## Key Patterns

- `lib.mkIf cfg.flag` — conditional configuration
- `lib.mkDefault value` — overridable default; consumers can override with `=`
- `lib.mkForce value` — override that cannot be overridden downstream
- `lib.mkMerge [ ... ]` — combine multiple conditional blocks safely
- Feature flags cascade: `marchyo.desktop.enable = true` auto-enables media, office, etc. via `lib.mkDefault`

## Common Pitfalls

- Always run `nix fmt` before committing — CI will fail without it
- Never define `marchyo.*` options outside `modules/nixos/options/`
- Auto-discovery imports every `.nix` file under `modules/{nixos,home}/` — leftover scratch files become dead modules
- Tests are evaluation-only (no builds) — use `testNixOS` and `withTestUser`
- `allowUnfree = true` is set globally; no need to set it per-package
- `marchyo.inputMethod.*` is removed — use `marchyo.keyboard.layouts` instead
