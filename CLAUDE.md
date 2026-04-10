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
# Justfile recipes (preferred workflow)
just check               # Lint + eval checks (nix flake check, statix, deadnix)
just fmt                 # Format all Nix code (nixfmt, deadnix, statix, shellcheck, yamlfmt)
just build               # Build reference NixOS configuration
just update              # Update all pins in sync: npins -> devenv.lock -> flake.lock
just verify              # Verify all lock files reference the same nixpkgs rev
just vm                  # Run QEMU VM (x86_64-linux only)

# Direct Nix commands
nix flake check          # Validate configuration and run all tests
nix fmt                  # Format all Nix code via treefmt-nix
nix flake show           # Display all flake outputs
nix eval .#checks.x86_64-linux --apply builtins.attrNames  # List available tests

# Development shell
devenv shell             # Enter development shell (no experimental features needed)
```

There is no way to run a single test in isolation; `nix flake check` runs them all (they are fast evaluation-only checks).

## Code Style

- Format with `just fmt` (or `nix fmt`) before committing — this is mandatory, CI enforces it
- Follow conventional commit message format (e.g. `feat:`, `fix:`, `chore:`)
- Use `lib.mkIf cfg.someFlag` for conditional configuration
- Use `lib.mkDefault` for options that consumers should be able to override
- All custom options must be defined in `modules/nixos/options.nix` under the `marchyo.*` namespace

## Architecture

### Hybrid Non-Flake + Flake Architecture

All real Nix logic lives in plain Nix files. `flake.nix` is a thin re-export wrapper (~40 lines) that imports `default.nix` and forwards outputs. Development uses `devenv.sh` (no experimental features required). npins is the single source of truth for the nixpkgs revision, synchronized across `npins/sources.json`, `devenv.lock`, and `flake.lock`.

### Module Organization

```
default.nix         # Source of truth — takes { inputs }, returns all outputs
overlay.nix         # Nixpkgs overlay (vicinae, noctalia, worktrunk, hyprmon, plymouth-marchyo-theme)
flake.nix           # Thin re-export wrapper — imports default.nix, forwards outputs
treefmt.nix         # Formatter config for treefmt-nix
devenv.nix          # Development shell configuration
devenv.yaml         # devenv inputs (nixpkgs pinned to npins rev)
Justfile            # Task runner (check, fmt, build, update, verify)
statix.toml         # Statix linter configuration
npins/              # Nixpkgs pin — single source of truth for nixpkgs revision
modules/nixos/      # NixOS system-level modules (~31 modules)
modules/home/       # Home Manager user-level modules (~30 modules)
modules/generic/    # Shared modules imported by both nixos and home default.nix (no own default.nix)
packages/           # Custom Nix packages (hyprmon, plymouth-marchyo-theme)
tests/              # Evaluation-based test suite (no builds required)
disko/              # Disk partitioning configurations (not wired into flake outputs)
installer/          # ISO build configs (not wired into flake outputs)
templates/workstation/  # Developer workstation template
```

### Flake Outputs

- `nixosModules.default` — Main NixOS module (includes Home Manager)
- `homeModules.default` — Home Manager module only
- `overlays.default` — Nixpkgs overlay
- `templates.workstation` — Starter workstation template
- `apps.{system}.default` — QEMU VM runner with all features enabled (x86_64-linux only)
- `checks.{system}.*` — Test suite
- `nixosConfigurations.default` — Reference NixOS config used by CI build and VM runner

### Key Files

- `default.nix` — **Source of truth** for all outputs. Takes `{ inputs }:`, returns nixosModules, homeModules, overlays, templates, nixosConfigurations, and per-system constructors (mkChecks, mkFormatter, mkApps, legacyPackages).
- `overlay.nix` — Nixpkgs overlay. Takes `{ inputs }:`, returns `final: prev:` function exposing external packages (vicinae, noctalia, worktrunk) and custom packages (hyprmon, plymouth-marchyo-theme).
- `flake.nix` — Thin wrapper. Imports `default.nix` with flake inputs, wraps per-system outputs with `forAllSystems`.
- `npins/sources.json` — Single source of truth for the nixpkgs revision. All lock files sync to this.
- `modules/nixos/options.nix` — **All** `marchyo.*` options are defined here (~640 lines). Single source of truth for the option namespace.
- `modules/nixos/default.nix` — Import list for all NixOS modules (order matters for some modules).
- `modules/home/default.nix` — Import list for all Home Manager modules.
- `modules/nixos/input-migration.nix` — Assertions that enforce removal of deprecated `marchyo.inputMethod.*` options.
- `tests/default.nix` — Test suite entry point; combines module-tests and lib-tests.
- `tests/module-tests.nix` — Module evaluation tests with `testNixOS`/`withTestUser` helpers.
- `tests/lib-tests.nix` — Unit tests for lib functions using `assertTest` helper.

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

Tests in `tests/` are fast evaluation-based checks (no builds required). Two categories:
- **Module tests** (`module-tests.nix`): Verify NixOS configs evaluate without errors for various feature combinations (minimal, desktop, development, all features, themes, keyboard layouts, GPU configs, default apps).
- **Lib tests** (`lib-tests.nix`): Unit tests for lib functions using `assertTest` helper.

All changes must pass `just check` (or `nix flake check`).

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

Default schemes: `nord` (dark), `nord-light` (light). Stylix base16Scheme is set in `modules/nixos/default.nix`.

### Default Applications

When `marchyo.desktop.enable = true`, the `marchyo.defaults.*` options control which apps are installed and set as system defaults. Set any to `null` to skip management for that category.

```nix
marchyo.defaults = {
  browser = "google-chrome";      # brave, google-chrome, firefox, chromium
  editor = "jotain";              # emacs, jotain, vscode, vscodium, zed
  terminalEditor = "jotain";      # emacs, jotain, neovim, helix, nano
  videoPlayer = "mpv";            # mpv, vlc, celluloid
  audioPlayer = "mpv";            # mpv, vlc, amberol
  musicPlayer = "spotify";        # spotify
  fileManager = "nautilus";       # nautilus, thunar
  terminalFileManager = "yazi";   # yazi, ranger, lf
  imageEditor = "pinta";         # pinta, gimp, krita
  email = "gmail";               # gmail, thunderbird, outlook
};
```

`"jotain"` and web-based email (`"gmail"`, `"outlook"`) are externally managed — no package is installed by marchyo. The implementation is in `modules/nixos/defaults.nix`.

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

### Deprecated Options

- `marchyo.keyboard.variant` → use `{ layout = "us"; variant = "intl"; }` in layouts
- `marchyo.inputMethod.triggerKey` → **inert (has no effect)**, use `marchyo.keyboard.imeTriggerKey`
- `marchyo.inputMethod.enableCJK` → **inert (has no effect)**, add CJK entries to `marchyo.keyboard.layouts`

## Session Completion

**When ending a work session**, complete ALL steps below. Work is NOT complete until `git push` succeeds.

1. **Run quality gates** (if code changed) — `just check` and `just fmt`
2. **Push to remote** — This is MANDATORY:
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
3. **Verify** — All changes committed AND pushed

**Critical rule:** Work is NOT complete until `git push` succeeds.

## CI Pipeline

`.github/workflows/validate.yml` runs three stages on push to `main` and PRs:
1. **lints** — `nix fmt -- --ci` (formatting check only, no writes)
2. **check** — `nix flake check` (all evaluation tests)
3. **build** — `nix build .#nixosConfigurations.default.config.system.build.toplevel` (full system build, runs after lints and check pass)

Stages 1 and 2 run in parallel; stage 3 runs after both succeed.

Uses [Cachix](https://app.cachix.org) (`jylhis` cache) to speed up builds.

## Gotchas

- **Assertions for removed options**: `input-migration.nix` uses NixOS assertions to fail the build with migration instructions if anyone uses the removed `marchyo.inputMethod.*` options.
- **Deprecated options**: Some options emit warnings but still work. They are defined in `options.nix` with deprecation notes in their descriptions.
- **`marchyo.theme.scheme` is defined but not consumed**: The option exists in `options.nix` but no module reads it. Stylix `base16Scheme` is hardcoded to `nord`/`nord-light` in `modules/nixos/default.nix`. Setting `marchyo.theme.scheme` currently has no effect.
- **Unreferenced module files**: `modules/nixos/powersave.nix` and `modules/nixos/audio.nix` exist on disk but are not imported by `modules/nixos/default.nix`. Similarly, `disko/` and `installer/` directories are not wired into flake outputs.
- **`allowUnfree = true`**: Set globally in `legacyPackages` (via `default.nix`) and in test configs.
- **Formatter runs multiple tools**: `nix fmt` runs nixfmt, deadnix (unused vars), statix (linting), shellcheck, and yamlfmt via treefmt-nix (`treefmt.nix`). All must pass.
- **Nixpkgs pin sync**: npins is the single source of truth. Run `just update` to bump nixpkgs and sync all lock files. Run `just verify` to check they're aligned. Renovate can update `flake.lock` but won't update npins — `just verify` in CI catches drift.
- **No standalone Home Manager tests**: The test suite only evaluates full NixOS configs (which include Home Manager). There are no tests that evaluate `homeModules` in isolation.
- **`docs/`**: Contains Mintlify documentation. The `README.md` links to it. Option documentation in `docs/configuration/` should be kept in sync with `options.nix`.
