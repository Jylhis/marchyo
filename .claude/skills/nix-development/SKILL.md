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

1. Create `modules/nixos/<name>.nix`
2. Add the import to `modules/nixos/default.nix`
3. If the module needs new options, add them to `modules/nixos/options.nix` under `marchyo.*`

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

1. Create `modules/home/<name>.nix`
2. Add the import to `modules/home/default.nix`

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

All options go in `modules/nixos/options.nix` under `marchyo.*`:

```nix
marchyo = {
  myFeature = {
    enable = lib.mkEnableOption "my feature";
    setting = lib.mkOption {
      type = lib.types.str;
      default = "default-value";
      description = "Description of the setting.";
    };
  };
};
```

## Writing Tests

Add evaluation tests to `tests/module-tests.nix`:

```nix
eval-my-feature = testNixOS "my-feature" (withTestUser {
  marchyo.myFeature.enable = true;
});
```

The `testNixOS` helper evaluates the NixOS config without building derivations. The `withTestUser` helper merges your config with a minimal bootable config.

## Key Patterns

- `lib.mkIf cfg.someFlag` — conditional configuration
- `lib.mkDefault value` — overridable default (consumers can override with `=` assignment)
- `lib.mkForce value` — override that cannot be overridden downstream
- `lib.mkMerge [ ... ]` — combine multiple conditional blocks safely
- Feature flags follow the pattern: enable entire stack with one boolean

## Common Pitfalls

- Always run `nix fmt` before committing — CI will fail without it
- Never define options outside `modules/nixos/options.nix`
- When using `lib.mkDefault`, consumers can still override; use regular assignment if you want a hard default
- Importing a module in `default.nix` is required — creating the file alone is not enough
- Tests are evaluation-only (no builds) — use the `testNixOS` and `withTestUser` helpers in `tests/module-tests.nix`
