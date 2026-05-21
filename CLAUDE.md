# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Marchyo is a modular NixOS configuration flake providing curated system, Home Manager, and nix-darwin configurations with sensible defaults. It is distributed as a Nix flake meant to be used as the sole input in downstream NixOS or nix-darwin configurations (nixpkgs passes through via `marchyo.inputs.nixpkgs`).

**Key features:**
- Modular architecture: configurations broken into small, manageable modules
- Feature flags: `marchyo.desktop.enable`, `marchyo.development.enable`, etc. enable entire stacks
- Home Manager integration for user-specific configurations and dotfiles
- nix-darwin support for macOS system configuration
- Hardware support via `nixos-hardware` with NVIDIA/PRIME graphics options
- All custom options live under the `marchyo.*` namespace
- Nixpkgs passthrough: downstream consumers only need `inputs.marchyo`

## Commands

```bash
# Justfile recipes (preferred workflow)
just check               # Lint + eval checks (nix flake check, statix, deadnix)
just fmt                 # Format all Nix code (nixfmt, deadnix, statix, shellcheck, yamlfmt)
just build               # Build reference NixOS configuration
just update              # Update all inputs: flake.lock -> devenv.lock
just verify              # Verify flake.lock and devenv.lock reference the same nixpkgs rev
just run                 # Run default configuration VM (x86_64-linux only)
just vm                  # Alias for just run

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
- All custom options must be defined under `modules/nixos/options/` in the `marchyo.*` namespace (one file per logical namespace; auto-discovered)

## Architecture

### Hybrid Non-Flake + Flake Architecture

All real Nix logic lives in plain Nix files. `flake.nix` is a thin re-export wrapper that imports `outputs.nix` and forwards outputs. `default.nix` is a flake-compat shim for non-flake consumers (devenv, `nix-build`). Development uses `devenv.sh` (no experimental features required). `flake.lock` is the single source of truth for the nixpkgs revision, synchronized to `devenv.lock` via `just update`.

### Module Organization

```
flake.nix           # Flake entry point — imports outputs.nix, wraps per-system outputs
flake.lock          # Single source of truth for all pinned inputs (nixpkgs, home-manager, etc.)
outputs.nix         # All output logic — takes { inputs }, returns modules, packages, checks, etc.
default.nix         # Flake-compat shim — exposes flake outputs to non-flake consumers
overlay.nix         # Nixpkgs overlay (vicinae, noctalia, hyprmon, plymouth-marchyo-theme, plus jylhis-design)
treefmt.nix         # Formatter config for treefmt-nix
devenv.nix          # Development shell configuration
devenv.yaml         # devenv inputs (nixpkgs pinned to same rev as flake.lock)
Justfile            # Task runner (check, fmt, build, update, verify)
statix.toml         # Statix linter configuration
modules/nixos/      # NixOS system-level modules (~31 modules)
modules/darwin/     # nix-darwin modules (imports shared options + generic modules)
modules/home/       # Home Manager user-level modules (~30 modules)
modules/generic/    # Shared modules imported by nixos, darwin, and home default.nix
packages/           # Custom Nix packages (hyprmon, plymouth-marchyo-theme)
tests/              # Evaluation-based test suite (no builds required)
disko/              # Disk partitioning configurations (not wired into flake outputs)
installer/          # ISO build configs (not wired into flake outputs)
templates/workstation/  # Developer workstation template
```

### Flake Outputs

- `nixosModules.default` — Main NixOS module (includes Home Manager, Stylix, overlay)
- `nixosModules.home-manager` — Re-exported home-manager NixOS module
- `darwinModules.default` — nix-darwin module (includes Home Manager, overlay)
- `homeManagerModules.default` — Home Manager module only
- `homeManagerModules._1password` — 1Password Home Manager module
- `overlays.default` — Nixpkgs overlay (darwin-safe: Linux packages wrapped in `optionalAttrs`)
- `packages.{linux}.hyprmon` — Hyprland monitor management tool
- `packages.{linux}.plymouth-marchyo-theme` — Plymouth boot splash theme
- `legacyPackages.{system}` — Full nixpkgs with overlay applied
- `templates.workstation` — Starter workstation template (uses nixpkgs passthrough)
- `apps.x86_64-linux.default` — QEMU VM runner with all features enabled
- `checks.{linux}.*` — Evaluation test suite
- `formatter.{system}` — treefmt wrapper (shared config with devenv)
- `nixosConfigurations.{x86_64,aarch64}` — Reference NixOS configs (Linux); `x86_64` is built by CI and backs the VM runner
- `darwinConfigurations.{aarch64,x86_64}` — Reference nix-darwin configs
- `homeConfigurations.{x86_64-linux,aarch64-linux}` — Standalone Home Manager configs (Linux only)

Downstream consumers access nixpkgs via `marchyo.inputs.nixpkgs` — no separate nixpkgs input needed.

### Key Files

- `flake.nix` — Flake entry point. Imports `outputs.nix` with flake inputs, wraps per-system outputs with `forAllSystems`. Includes `flake-compat` as a non-flake input.
- `flake.lock` — **Single source of truth** for all pinned input revisions (nixpkgs, home-manager, stylix, etc.). `devenv.lock` syncs to this via `just update`.
- `outputs.nix` — All output logic. Takes `{ inputs }:`, returns nixosModules, darwinModules, homeManagerModules, overlays, templates, nixosConfigurations, and per-system constructors (mkPackages, mkChecks, mkFormatter, mkApps, legacyPackages).
- `default.nix` — Flake-compat shim. Uses `flake-compat` (pinned in `flake.lock`) to expose flake outputs to non-flake consumers (`nix-build`, devenv).
- `overlay.nix` — Nixpkgs overlay. Takes `{ inputs }:`, returns `final: prev:` function. All packages are Linux-only (wrapped in `lib.optionalAttrs stdenv.isLinux`).
- `lib/systems.nix` — Single source of truth for the system list. `flake.nix` imports `{ linux, darwin, all }` from here; adding/removing a system is a one-file change.
- `lib/discover-modules.nix` — Auto-discovery helper. Returns every `.nix` file directly under a given directory (excluding `default.nix`) plus any subdirectory containing `default.nix`. Used by `modules/{nixos,home}/default.nix` and `modules/nixos/options/default.nix`.
- `modules/nixos/options/` — `marchyo.*` option declarations split by namespace (users, defaults, feature-flags, performance, graphics, localization, theme, keyboard, tracking, deprecated). The directory's `default.nix` auto-imports every file.
- `modules/nixos/default.nix` — Auto-discovers every NixOS module via `lib/discover-modules.nix`. Module merging is order-independent at the option/config layer; use `mkBefore`/`mkAfter`/priorities if a specific merge order matters.
- `modules/darwin/default.nix` — **Manual** import list for nix-darwin modules. Curated subset (Wayland/systemd/desktop modules are NixOS-only and intentionally excluded). Imports `../nixos/options` for the shared option namespace.
- `modules/home/default.nix` — Auto-discovers every Home Manager module via `lib/discover-modules.nix`.
- `modules/nixos/input-migration.nix` — Assertions that enforce removal of deprecated `marchyo.inputMethod.*` options.
- `tests/default.nix` — Test suite entry point. Auto-discovers every file in `tests/eval/` and merges the attrsets they return; appends `lib-tests.nix`.
- `tests/lib.nix` — Shared test helpers (`testNixOS`, `withTestUser`, `minimalConfig`).
- `tests/eval/*.nix` — Per-feature evaluation tests. Each file receives helpers + `lib`/`pkgs`/`nixosModules`/`homeManagerModules` and returns an attrset of named tests.
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

## Testing

Tests in `tests/` are fast evaluation-based checks (no builds required). Two categories:
- **Module tests** (`tests/eval/*.nix`, auto-discovered): verify NixOS configs evaluate without errors for various feature combinations (minimal/feature-flags, themes, keyboard, graphics, defaults, tracking, hyprland config check).
- **Lib tests** (`tests/lib-tests.nix`): unit tests for lib functions using `assertTest` helper.

All changes must pass `just check` (or `nix flake check`).

## Cross-Module Data Flow

The keyboard/IME system is the most complex cross-module pattern:
1. `modules/nixos/options/keyboard.nix` — defines `marchyo.keyboard.layouts` accepting strings or attrsets
2. `modules/nixos/keyboard.nix` — normalizes layouts (string `"us"` → `{ layout = "us"; variant = ""; ime = null; }`) and sets XKB config
3. `modules/nixos/fcitx5.nix` — reads normalized layouts, detects which IME addons are needed, generates fcitx5 config
4. `modules/home/keyboard.nix` — extracts layout data into `home.keyboard` for Hyprland
5. `modules/home/hyprland.nix` — reads `osConfig.marchyo.graphics` for GPU-specific env vars and keyboard from `home.keyboard`

## Available Options Reference

### Feature Flags

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.desktop.enable` | `false` | Desktop (Hyprland, audio, bluetooth, fonts) |
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
};
```

Stylix `base16Scheme` is hardcoded in `modules/nixos/default.nix`: `nord` for dark, `nord-light` for light. To customize the scheme, override `stylix.base16Scheme` directly in your config.

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

**When ending a work session**, complete ALL steps below. Work is NOT complete until changes are committed.

1. **Run quality gates** (if code changed) — `just check` and `just fmt`
2. **Verify** — All changes committed

## CI Pipeline

`.github/workflows/validate.yml` runs three stages on push to `main` and PRs:
1. **lint** — `nix fmt -- --ci` (formatting check) plus the `flake.lock` / `devenv.lock` rev-parity verification. Single `ubuntu-latest` runner (formatting and lockfile checks are platform-independent).
2. **check** — `nix flake check --accept-flake-config` matrix across `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`. `x86_64-darwin` is intentionally omitted — Nixpkgs 26.05 is the last release to support it and `aarch64-darwin` covers evaluation equivalently.
3. **build** — `nix build .#nixosConfigurations.x86_64.config.system.build.toplevel` (full system build, `ubuntu-latest` only, runs after both `lint` and `check` succeed).

Top-level `concurrency: ${{ github.workflow }}-${{ github.ref }}` cancels in-progress PR runs on new pushes (main runs are never canceled). Every job has a `timeout-minutes`.

`.github/workflows/pages.yml` builds and deploys docs to GitHub Pages. It only fires when `docs/**`, flake sources, or the workflow itself change.

Uses [Cachix](https://app.cachix.org) (`jylhis` cache) to speed up builds. Dependabot groups all `nix` and `github-actions` bumps into single weekly PRs.

## Gotchas

- **Assertions for removed options**: `input-migration.nix` uses NixOS assertions to fail the build with migration instructions if anyone uses the removed `marchyo.inputMethod.*` options.
- **Deprecated options**: Some options emit warnings but still work. They are defined in `modules/nixos/options/deprecated.nix` (and `keyboard.nix`'s `variant` field) with deprecation notes in their descriptions.
- **Auto-discovery of modules**: Both `modules/nixos/default.nix` and `modules/home/default.nix` use `lib/discover-modules.nix` to import every `.nix` file in the directory plus any subdirectory containing a `default.nix`. Adding a new module is one file — no import-list edit needed. The NixOS module system merges options/config order-independently, so the dropped explicit ordering is safe; reach for `mkBefore`/`mkAfter`/priorities if a specific merge order ever matters.
- **Theme source of truth**: All theme assets (palette, ANSI 16, Hyprland colors, Waybar CSS, Mako config, GTK overrides, fzf colors, bat tmThemes, starship.toml, ghostty themes, hyprlock colors, console.colors) come from `pkgs.jylhis-design-src` (the unpacked `inputs.jylhis-design` flake input). The base16 mapping is computed from `tokens.json` by `modules/generic/jylhis-palette.nix`'s `mkPalette { variant, pkgs, lib }` helper. The upstream `${inputs.jylhis-design}/nix/home-manager-module.nix` is imported via `modules/home/jylhis-theme.nix` and writes ghostty themes, mako config, gtk CSS, starship.toml, and `FZF_DEFAULT_OPTS` directly. Only `marchyo.theme.scheme = "<name>"` overrides this and points at a `pkgs.base16-schemes` YAML instead.
- **Stylix target disablement**: marchyo overrides Stylix for surfaces it themes directly: `plymouth, hyprland, waybar, mako, ghostty, gtk, fzf, bat, hyprlock, console, starship`. See `modules/generic/theme.nix`. The remaining Stylix targets (qt, vicinae, kde, gnome, fontconfig, …) still receive base16-derived theming.
- **`disko/` and `installer/` are starter snippets**: They are not wired into flake outputs. Copy the file you need into a downstream host configuration; they're versioned here as templates, not as a stable API.
- **`allowUnfree = true`**: Set globally in `legacyPackages` (via `outputs.nix`) and in test configs.
- **Formatter runs multiple tools**: `nix fmt` runs nixfmt, deadnix (unused vars), statix (linting), shellcheck, and yamlfmt via treefmt-nix (`treefmt.nix`). All must pass.
- **Nixpkgs pin sync**: `flake.lock` is the single source of truth for the nixpkgs revision and all other flake inputs. Run `just update` to bump all inputs and sync `devenv.lock` to the same nixpkgs rev (`nix flake update` → extract rev → update `devenv.yaml` → `devenv update`). Run `just verify` to check they're aligned. Renovate updates `flake.lock` independently via `lockFileMaintenance` but does not update `devenv.lock` — CI's `verify` job catches this drift so the PR will fail until `just update` is run to re-sync.
- **No standalone Home Manager tests**: The test suite only evaluates full NixOS configs (which include Home Manager). There are no tests that evaluate `homeManagerModules` in isolation.
- **Shared treefmt config**: `treefmt.nix` is the single source of truth for formatting. Both the flake formatter (`nix fmt`) and the devenv shell (`treefmt`) use it. devenv.yaml includes `treefmt-nix` as an input for this purpose.
- **Darwin module is intentionally minimal**: `darwinModules.default` imports the shared option namespace (`modules/nixos/options/`), nix-settings, and generic modules. Desktop/Wayland/systemd modules are NixOS-only. Unlike the auto-discovered NixOS/home lists, `modules/darwin/default.nix` is a hand-curated subset — keep it that way. The overlay is embedded but all packages are Linux-only (`optionalAttrs`).
- **Nixpkgs passthrough**: All flake inputs use `follows = "nixpkgs"`. Downstream consumers access nixpkgs via `marchyo.inputs.nixpkgs` — no separate nixpkgs input needed. The workstation template demonstrates this pattern.
- **`docs/`**: Contains Mintlify documentation. The `README.md` links to it. Option documentation in `docs/configuration/` should be kept in sync with the option declarations under `modules/nixos/options/`.
- **Tracking cascade auto-enables auditd**: `marchyo.tracking.enable = true` flips every sub-collector on via `lib.mkDefault`, including `system.auditd` (kernel audit subsystem with execve + per-user `~/.config` watch rules). To opt out without disabling the whole stack: `marchyo.tracking.system.auditd = false`. Tuning knobs live under `marchyo.tracking.system.auditd*` (backlog limit, failure mode, log rotation, ruleset lock, early-boot kernel cmdline) — see `modules/nixos/options/tracking.nix` and `modules/nixos/tracking/system.nix`.
- **Laurel audisp plugin**: `modules/nixos/tracking/laurel.nix` is enabled when `system.auditd && aggregation.enable` are both on. It runs as the `_laurel` system user, writes JSONL to `/var/log/laurel/audit.log`, and that file is added to the Vector source list in `modules/nixos/tracking/aggregation.nix`. Laurel is the only path by which kernel audit events reach the Loki sink — the raw `/var/log/audit/audit.log` is never read by Vector directly.
- **`config_changes` watch overlap**: When `system.auditd && system.fileWatch` are both on (the default cascade), `~/.config` is observed by both auditd's syscall watch and the per-user inotifywait service. Kept by design — they capture different things — but worth knowing if you see duplicated-looking events in aggregation output.
