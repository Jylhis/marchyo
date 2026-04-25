---
name: nix-development
description: NixOS and Home Manager module development for the Marchyo flake. Use when adding modules, defining options, writing tests, or modifying the NixOS/Home Manager configuration structure.
user-invocable: true
argument-hint: "[module-name or task description]"
---

# Nix Development Skill

This skill covers development workflows for the Marchyo NixOS configuration flake.

## Key Commands

```bash
nix flake check     # Validate and run all tests (REQUIRED before committing)
nix fmt             # Format all Nix code (REQUIRED before committing)
nix develop         # Enter development shell with all tools
nix flake show      # Inspect all flake outputs
nix eval .#checks.x86_64-linux --apply builtins.attrNames  # List tests
```

## Adding a New NixOS Module

1. Create `modules/nixos/<name>.nix` — auto-discovered by `lib/discover-modules.nix`, no import edit needed
2. If the module needs new options, add them to a file under `modules/nixos/options/` (or create a new namespace file)

```nix
# modules/nixos/example.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.someFlag {
    # configuration here
  };
}
```

## Adding a New Home Manager Module

1. Create `modules/home/<name>.nix` — auto-discovered, no import edit needed

```nix
# modules/home/example.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.someFlag {
    home.packages = [ pkgs.somePackage ];
  };
}
```

## Adding a New nix-darwin Module

`modules/darwin/` is a curated subset, **not** auto-discovered:
1. Create `modules/darwin/<name>.nix`
2. Add an import line to `modules/darwin/default.nix` manually

## Defining New Options

Options live under `modules/nixos/options/` — pick the matching namespace file or create a new one. Each file declares `options.marchyo.<namespace>` and is auto-imported by `modules/nixos/options/default.nix`.

```nix
# modules/nixos/options/my-feature.nix
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.myFeature = {
    enable = lib.mkEnableOption "my feature";
    setting = mkOption {
      type = types.str;
      default = "default-value";
      description = "Description of the setting.";
    };
  };
}
```

## Writing Tests

Drop tests into the matching `tests/eval/<feature>.nix` (or create a new file there). Each file is a function returning an attrset of named tests:

```nix
# tests/eval/my-feature.nix
{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
in
{
  eval-my-feature = testNixOS "my-feature" (withTestUser {
    marchyo.myFeature.enable = true;
  });
}
```

The `testNixOS` helper evaluates the NixOS config without building derivations. The `withTestUser` helper merges your config with a minimal bootable config. Files in `tests/eval/` are auto-discovered.

## Key Patterns

- `lib.mkIf cfg.someFlag` — conditional configuration
- `lib.mkDefault value` — overridable default (consumers can override with `=` assignment)
- `lib.mkForce value` — override that cannot be overridden downstream
- `lib.mkMerge [ ... ]` — combine multiple conditional blocks safely
- Feature flags follow the pattern: enable entire stack with one boolean

## Common Pitfalls

- Always run `nix fmt` before committing — CI will fail without it
- Never define options outside `modules/nixos/options/`
- Auto-discovery imports every `.nix` file under `modules/{nixos,home}/` — leftover scratch files become dead modules
- Tests are evaluation-only (no builds) — use the `testNixOS` and `withTestUser` helpers from `tests/lib.nix`
