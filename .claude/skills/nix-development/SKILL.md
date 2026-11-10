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
just check-full     # Also build the heavy checks (Hyprland config, theme assets, Plymouth)
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

A test is a named predicate over one of the shared reference systems in `tests/lib.nix` (`refBases`): a function from the evaluated NixOS `config` to `true`, `false`, a failure message or a list of failure messages. Each reference system is evaluated once and is one check, `ref-<name>`, that lists every failing predicate by name. Add the predicate to the system that already has the configuration you need (`desktop`, `headless`, `full`, …); a non-default setting goes on a tweak system (`desktop-tweaks`, `headless-tweaks-2`, `desktop-off`, …) through `refConfig`, in the same file:

```nix
# tests/eval/my-feature.nix
{ helpers, lib, ... }:
{
  refs.desktop.eval-my-feature-default = cfg: cfg.services.my-feature.enable;

  refs.desktop-tweaks.eval-my-feature-port =
    cfg: helpers.expect (lib.elem 1234 cfg.networking.firewall.allowedTCPPorts) "port 1234 is not open";
  refConfig.desktop-tweaks.marchyo.myFeature.port = 1234;
}
```

Negative tests go in `failing` (`{ on = "misconfigured"; expect = "assertion text"; }` plus `failingConfig.misconfigured`), one-off configurations in `variants`, build checks in `heavy` (built by `just check-full`, not `nix flake check`). Files in `tests/eval/` are auto-discovered; `tests/README.md` has the details. Avoid calling `helpers.mkSystem` per test: every call is a full evaluation.

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
- Default checks are evaluation-only: add predicates to the shared reference systems in `tests/lib.nix` rather than evaluating a new system per test; anything that builds goes in `heavy`
