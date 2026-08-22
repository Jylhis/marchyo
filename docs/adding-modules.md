# Adding modules & module patterns

## Code Style

- Format with `just fmt` (or `nix fmt`) before committing — this is mandatory, CI enforces it
- Follow conventional commit message format (e.g. `feat:`, `fix:`, `chore:`)
- Use `lib.mkIf cfg.someFlag` for conditional configuration
- Use `lib.mkDefault` for options that consumers should be able to override
- All custom options must be defined under `modules/nixos/options/` in the `marchyo.*` namespace (one file per logical namespace; auto-discovered)

## Module Patterns

### Standard NixOS module structure

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

### Home Manager modules accessing NixOS config

Home Manager modules receive the NixOS config via `osConfig`:

```nix
{ config, lib, osConfig ? {}, ... }:
let
  cfg = osConfig.marchyo or {};
in
{ ... }
```

### Feature flag cascading

When `marchyo.desktop.enable = true`, the desktop-config module auto-enables related flags with `lib.mkDefault` so consumers can override:

```nix
marchyo.office.enable = lib.mkDefault true;
marchyo.media.enable = lib.mkDefault true;
```

### `lib.mkDefault` vs `lib.mkIf`

- `lib.mkDefault` — sets a value at lower priority; consumers can override it. Use for defaults that should be changeable.
- `lib.mkIf condition { ... }` — conditionally includes an entire config block. Use for feature-gated sections.
- `lib.mkMerge [ ... ]` — combines multiple conditional blocks safely when a module has several `mkIf` branches.

## Adding a New Module

1. Create the file in `modules/nixos/`, `modules/home/`, or `modules/generic/` — auto-discovery picks it up on the next eval (no import edit needed for nixos/home).
   - For `modules/darwin/`, add the import to `modules/darwin/default.nix` manually (curated subset).
2. Define any new options in a file under `modules/nixos/options/` — auto-discovery picks them up. Use an existing namespace file or create a new one (`mychunk.nix`) declaring `options.marchyo.<namespace>`.
3. Add an evaluation test in the appropriate `tests/eval/<feature>.nix`, or create a new file there:

```nix
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

The `testNixOS` helper evaluates the NixOS config without building derivations. The `withTestUser` helper merges your config with a minimal bootable config (grub disabled, root filesystem, stateVersion). Tests are auto-discovered from `tests/eval/`.

## Cross-Module Data Flow

The keyboard/IME system is the most complex cross-module pattern:
1. `modules/nixos/options/keyboard.nix` — defines `marchyo.keyboard.layouts` accepting strings or attrsets
2. `modules/nixos/keyboard.nix` — normalizes layouts (string `"us"` → `{ layout = "us"; variant = ""; ime = null; }`) and sets XKB config
3. `modules/nixos/fcitx5.nix` — reads normalized layouts, detects which IME addons are needed, generates fcitx5 config
4. `modules/home/keyboard.nix` — extracts layout data into `home.keyboard` for Hyprland
5. `modules/home/hyprland.nix` — reads `osConfig.marchyo.graphics` for GPU-specific env vars and keyboard from `home.keyboard`
