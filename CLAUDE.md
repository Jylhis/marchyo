# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Marchyo is a modular NixOS configuration flake providing curated system and Home Manager configurations with sensible defaults. It is distributed as a Nix flake meant to be used as an input in other NixOS configurations.

**Key features:**
- Modular architecture: configurations broken into small, manageable modules
- Feature flags: `marchyo.desktop.enable`, `marchyo.development.enable`, etc. enable entire stacks
- Home Manager integration for user-specific configurations and dotfiles
- Hardware support via `nixos-hardware` with NVIDIA/PRIME graphics options
- All custom options live under the `marchyo.*` namespace

## Commands

```bash
nix flake check          # Validate configuration and run all tests (run before every commit)
nix fmt                  # Format all Nix code (nixfmt, deadnix, statix, shellcheck, yamlfmt) — run before every commit
nix develop              # Enter development shell
nix flake show           # Display all flake outputs
nix eval .#checks.x86_64-linux --apply builtins.attrNames  # List available tests
```

Running a VM for local testing:

```bash
nix run -L '.#nixosConfigurations.default.config.system.build.vmWithDisko'
```

There is no way to run a single test in isolation; `nix flake check` runs them all (they are fast evaluation-only checks).

## Code Style

- Format with `nix fmt` before committing — this is mandatory, CI enforces it
- Follow conventional commit message format (e.g. `feat:`, `fix:`, `chore:`)
- Use `lib.mkIf cfg.someFlag` for conditional configuration
- Use `lib.mkDefault` for options that consumers should be able to override
- All custom options must be defined in `modules/nixos/options.nix` under the `marchyo.*` namespace

## Architecture

### Module Organization

```
modules/nixos/      # NixOS system-level modules (~30 modules)
modules/home/       # Home Manager user-level modules (~33 modules)
modules/generic/    # Shared modules used by both (fontconfig, git, shell, packages, theme)
packages/           # Custom Nix packages (hyprmon, plymouth-marchyo-theme)
overlays/           # Nixpkgs overlays (vicinae, noctalia, worktrunk)
tests/              # Evaluation-based test suite (no builds required)
disko/              # Disk partitioning configurations
templates/workstation/  # Developer workstation template
```

### Flake Outputs

- `nixosModules.default` — Main NixOS module (includes Home Manager)
- `homeModules.default` — Home Manager module only
- `overlays.default` — Nixpkgs overlay
- `templates.workstation` — Starter workstation template
- `checks.{system}.*` — Test suite

### Key Files

- `modules/nixos/options.nix` — **All** `marchyo.*` options are defined here (~470 lines). Single source of truth for the option namespace.
- `modules/nixos/default.nix` — Import list for all NixOS modules (order matters for some modules).
- `modules/home/default.nix` — Import list for all Home Manager modules.
- `modules/generic/default.nix` — Shared modules imported by both NixOS and Home Manager.
- `modules/nixos/input-migration.nix` — Assertions that enforce removal of deprecated `marchyo.inputMethod.*` options.
- `tests/module-tests.nix` — All module evaluation tests with helper functions.

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

1. Create the file in `modules/nixos/`, `modules/home/`, or `modules/generic/`
2. Add the import to the corresponding `default.nix`
3. Define any new options in `modules/nixos/options.nix` under `marchyo.*`
4. Add an evaluation test in `tests/module-tests.nix`:

```nix
eval-my-feature = testNixOS "my-feature" (withTestUser {
  marchyo.myFeature.enable = true;
});
```

The `testNixOS` helper evaluates the NixOS config without building derivations. The `withTestUser` helper merges your config with a minimal bootable config (grub disabled, root filesystem, stateVersion).

## Testing

Tests in `tests/` are fast evaluation-based checks (no builds required). They cover module imports for various feature combinations: minimal, desktop, development, all features, themes, keyboard layouts, GPU configs.

All changes must pass `nix flake check`.

## Cross-Module Data Flow

The keyboard/IME system is the most complex cross-module pattern:
1. `modules/nixos/options.nix` — defines `marchyo.keyboard.layouts` accepting strings or attrsets
2. `modules/nixos/keyboard.nix` — normalizes layouts (string `"us"` → `{ layout = "us"; variant = ""; ime = null; }`) and sets XKB config
3. `modules/nixos/fcitx5.nix` — reads normalized layouts, detects which IME addons are needed, generates fcitx5 config
4. `modules/home/keyboard.nix` — extracts layout data into `home.keyboard` for Hyprland
5. `modules/home/hyprland.nix` — reads `osConfig.marchyo.graphics` for GPU-specific env vars and keyboard from `home.keyboard`

## Available Options Reference

### Feature Flags

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.desktop.enable` | `false` | Desktop (Hyprland, audio, bluetooth, fonts) |
| `marchyo.desktop.useWofi` | `false` | Use wofi instead of vicinae launcher |
| `marchyo.development.enable` | `false` | Dev tools (git, docker, virtualization) |
| `marchyo.media.enable` | `false` | Media apps (auto-enabled with desktop) |
| `marchyo.office.enable` | `false` | Office apps (auto-enabled with desktop) |

### User Configuration

```nix
marchyo.users.<username> = {
  enable = true;
  fullname = "Your Name";
  email = "your@email.com";
};
```

### Localization

| Option | Default | Example |
|--------|---------|---------|
| `marchyo.timezone` | `"Europe/Zurich"` | `"America/New_York"` |
| `marchyo.defaultLocale` | `"en_US.UTF-8"` | `"de_DE.UTF-8"` |

### Theming

```nix
marchyo.theme = {
  enable = true;
  variant = "dark";   # or "light"
  scheme = "dracula"; # any nix-colors scheme, or null for defaults
};
```

Default schemes: `modus-vivendi-tinted` (dark), `modus-operandi-tinted` (light).

### Keyboard & Input Methods

```nix
marchyo.keyboard = {
  layouts = [
    "us"
    { layout = "fi"; }
    { layout = "us"; variant = "intl"; }
    { layout = "cn"; ime = "pinyin"; }
    { layout = "jp"; ime = "mozc"; }
    { layout = "kr"; ime = "hangul"; }
  ];
  options = [ "grp:win_space_toggle" ];
  autoActivateIME = true;
  imeTriggerKey = [ "Super+I" ];
};
```

### Graphics (GPU)

```nix
marchyo.graphics = {
  vendors = [ "intel" ]; # "intel", "amd", "nvidia"
  nvidia.open = true;    # Open-source drivers (RTX 20xx+)
  prime = {
    enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
    mode = "offload"; # "offload", "sync", "reverse-sync"
  };
};
```

To find GPU bus IDs: `lspci | grep -E 'VGA|3D'`

## Breaking Changes

### `marchyo.inputMethod.*` is REMOVED

These options have been removed. Using them causes a build failure. Migrate to `marchyo.keyboard.layouts`:

```nix
# Old (error):
marchyo.inputMethod.enable = true;
marchyo.inputMethod.enableCJK = true;

# New:
marchyo.keyboard.layouts = [
  "us"
  { layout = "cn"; ime = "pinyin"; }
];
```

### Deprecated Options (still work, will be removed)

- `marchyo.keyboard.variant` → use `{ layout = "us"; variant = "intl"; }` in layouts
- `marchyo.inputMethod.triggerKey` → use `marchyo.keyboard.imeTriggerKey`
- `marchyo.inputMethod.enableCJK` → add CJK entries to `marchyo.keyboard.layouts`

## Gotchas

- **Assertions for removed options**: `input-migration.nix` uses NixOS assertions to fail the build with migration instructions if anyone uses the removed `marchyo.inputMethod.*` options.
- **Deprecated options**: Some options emit warnings but still work. They are defined in `options.nix` with deprecation notes in their descriptions.
- **`allowUnfree = true`**: The flake sets this globally in `legacyPackages` and in test configs.
- **Formatter runs multiple tools**: `nix fmt` runs nixfmt, deadnix (unused vars), statix (linting), shellcheck, and yamlfmt via treefmt-nix. All must pass.
- **No standalone Home Manager tests**: The test suite only evaluates full NixOS configs (which include Home Manager). There are no tests that evaluate `homeModules` in isolation.
