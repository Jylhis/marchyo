# Architecture

## Project Overview

Marchyo is a modular NixOS configuration flake providing curated system, Home Manager, and nix-on-droid configurations with sensible defaults. It is distributed as a batteries-included Nix flake meant to be used as the sole input in downstream configurations: consumers build with the `marchyo.lib.mkNixosSystem` builder, which selects the system-correct nixpkgs + home-manager automatically.

**Key features:**
- Modular architecture: configurations broken into small, manageable modules
- Feature flags: `marchyo.desktop.enable`, `marchyo.development.enable`, etc. enable entire stacks
- Home Manager integration for user-specific configurations and dotfiles
- nix-on-droid support for an Android terminal environment (CLI-only), a first-class build target via `marchyo.lib.mkNixOnDroidConfiguration`
- Hardware support via `nixos-hardware` with NVIDIA/PRIME graphics options
- All custom options live under the `marchyo.*` namespace
- Multi-nixpkgs: the primary `nixpkgs` input is **unstable**; `home-manager` tracks `master` to pair with unstable. nix-on-droid is pinned independently (its own 2024-era nixpkgs + `home-manager-droid`).
- Nixpkgs passthrough: downstream consumers only need `inputs.marchyo`; `marchyo.lib.*` builders and `legacyPackages.<system>` give a system-correct nixpkgs

## Hybrid Non-Flake + Flake Architecture

All real Nix logic lives in plain Nix files. `flake.nix` is a thin re-export wrapper that imports `outputs.nix` and forwards outputs. `default.nix` is a flake-compat shim for non-flake consumers (devenv, `nix-build`). Development uses `devenv.sh` (no experimental features required). `flake.lock` is the source of truth for input revisions; the devenv dev shell tracks the primary (unstable) `nixpkgs`, synchronized to `devenv.lock` via `just update`.

## Module Organization

```
flake.nix           # Flake entry point — imports outputs.nix, wraps per-system outputs
flake.lock          # Single source of truth for all pinned inputs (nixpkgs, home-manager, etc.)
outputs.nix         # All output logic — takes { inputs }, returns modules, packages, checks, etc.
default.nix         # Flake-compat shim — exposes flake outputs to non-flake consumers
overlay.nix         # Nixpkgs overlay (marchyo-cli/-shell/-wallpapers, plymouth-marchyo-theme, plus the vendored design system in lib/design)
treefmt.nix         # Formatter config for treefmt-nix
devenv.nix          # Development shell configuration
devenv.yaml         # devenv inputs (nixpkgs pinned to same rev as flake.lock)
Justfile            # Task runner (check, fmt, build, update, verify)
statix.toml         # Statix linter configuration
docs/               # Contributor/system-architecture reference (this tree)
manual/             # Published end-user documentation (rendered by site/)
shell/              # Quickshell shell QML tree, the default desktop shell (bar, launcher, OSD, panels, notifications, lock; see shell/README.md)
modules/nixos/      # NixOS system-level modules (auto-discovered)
modules/nix-on-droid/  # nix-on-droid (Android terminal): built via lib.mkNixOnDroidConfiguration; reuses generic git/shell modules; HM 24.05
modules/home/       # Home Manager user-level modules (auto-discovered)
modules/generic/    # Shared modules imported by nixos and home default.nix
packages/           # Custom Nix packages (marchyo-cli, marchyo-shell, plymouth-marchyo-theme, marchyo-wallpapers)
tests/              # Evaluation-based test suite (no builds required)
site/               # Astro + Starlight website (landing page + docs, marchyo.org)
disko/              # Disk partitioning configurations (not wired into flake outputs)
installer/          # ISO build configs (not wired into flake outputs)
templates/workstation/  # Developer workstation template
```

## Flake Outputs

- `lib.mkNixosSystem` — **Batteries-included system builder** (recommended consumer entry point). Take `{ system, modules ? [], specialArgs ? {} }` and auto-select the correct nixpkgs, home-manager, overlay and marchyo modules via the `inputsFor` selector in `outputs.nix`. The reference `nixosConfigurations` are built through this same builder. Also exported: `lib.mkNixOnDroidConfiguration` (batteries-included nix-on-droid builder, fixed to aarch64-linux; flows through the `droidInputs` grouping the way the others flow through `inputsFor`), `lib.mkHomeConfiguration`, `lib.inputsFor`, `lib.mkPkgs`
- `nixosModules.default` — Main NixOS module (includes Home Manager, overlay)
- `nixosModules.home-manager` — Re-exported home-manager NixOS module
- `homeManagerModules.default` — Home Manager module only
- `homeManagerModules._1password` — 1Password Home Manager module
- `overlays.default` — Nixpkgs overlay (Linux packages wrapped in `optionalAttrs`)
- `packages.{system}.{marchyo-cli,marchyo-wallpapers}` — cross-platform packages
- `packages.{linux}.{marchyo-shell,plymouth-marchyo-theme}` — Linux-only (Quickshell shell, Plymouth boot splash)
- `legacyPackages.{system}` — Full nixpkgs with overlay applied, **system-aware** (via `inputsFor`/`mkPkgs`)
- `templates.workstation` — Starter workstation template (uses nixpkgs passthrough)
- `apps.x86_64-linux.default` — QEMU VM runner with all features enabled
- `checks.{linux}.*` — Evaluation test suite
- `formatter.{system}` — treefmt wrapper (shared config with devenv)
- `nixosModules` / `homeManagerModules` / `nixOnDroidModules` — per-platform module sets
- `nixosConfigurations.{x86_64,aarch64}` — Reference NixOS configs (Linux, unstable), built through `lib.mkNixosSystem`; `x86_64` is built by CI and backs the VM runner
- `homeConfigurations.{x86_64-linux,aarch64-linux}` — Standalone Home Manager configs (Linux only)
- `nixOnDroidConfigurations.aarch64` — Reference Android terminal config, built through `lib.mkNixOnDroidConfiguration` (the same exported builder consumers use). Built impurely (`nix build --impure …activationPackage`): nix-on-droid uses `builtins.storePath`, so it cannot be evaluated in pure `nix flake check`. Coverage instead comes from `tests/eval/nix-on-droid.nix`, a pure check of the droid Home-Manager module (incl. the reused generic modules) against HM 24.05

Downstream consumers build with `marchyo.lib.mkNixosSystem`, which selects the system-correct nixpkgs automatically — no separate nixpkgs input needed. The raw `marchyo.inputs.nixpkgs` passthrough remains available but is always **unstable**; for a system-correct, overlay-applied package set use `marchyo.legacyPackages.<system>`.

## Key Files

- `flake.nix` — Flake entry point. Imports `outputs.nix` with flake inputs, wraps per-system outputs with `forAllSystems`. Includes `flake-compat` as a non-flake input.
- `flake.lock` — **Single source of truth** for all pinned input revisions (nixpkgs, home-manager, etc.). `devenv.lock` syncs to this via `just update`.
- `outputs.nix` — All output logic. Takes `{ inputs }:`, returns nixosModules, homeManagerModules, overlays, templates, nixosConfigurations, the `lib` builders (`mkNixosSystem` via the `inputsFor` per-system selector + `mkPkgs`), and per-system constructors (mkPackages, mkChecks, mkFormatter, mkApps, legacyPackages).
- `default.nix` — Flake-compat shim. Uses `flake-compat` (pinned in `flake.lock`) to expose flake outputs to non-flake consumers (`nix-build`, devenv).
- `overlay.nix` — Nixpkgs overlay. Takes `{ inputs }:`, returns `final: prev:` function. `marchyo-cli`/`marchyo-wallpapers` are cross-platform; Linux-only packages are wrapped in `lib.optionalAttrs stdenv.isLinux`.
- `lib/systems.nix` — Single source of truth for the system list. `flake.nix` imports `{ linux, all }` from here; adding/removing a system is a one-file change.
- `lib/discover-modules.nix` — Auto-discovery helper. Returns every `.nix` file directly under a given directory (excluding `default.nix`) plus any subdirectory containing `default.nix`. Used by `modules/{nixos,home}/default.nix` and `modules/nixos/options/default.nix`.
- `modules/nixos/options/` — `marchyo.*` option declarations, one file per namespace (feature-flags, users, localization, theme, keyboard, graphics, defaults, and many more). The directory's `default.nix` auto-imports every file, so adding a namespace is a one-file change.
- `modules/nixos/default.nix` — Auto-discovers every NixOS module via `lib/discover-modules.nix`. Module merging is order-independent at the option/config layer; use `mkBefore`/`mkAfter`/priorities if a specific merge order matters.
- `modules/home/default.nix` — Auto-discovers every Home Manager module via `lib/discover-modules.nix`.
- `tests/default.nix` — Test suite entry point. Auto-discovers every file in `tests/eval/` and merges the attrsets they return; appends `lib-tests.nix`.
- `tests/lib.nix` — Shared test helpers (`testNixOS`, `withTestUser`, `minimalConfig`).
- `tests/eval/*.nix` — Per-feature evaluation tests. Each file receives helpers + `lib`/`pkgs`/`nixosModules`/`homeManagerModules` and returns an attrset of named tests.
- `tests/lib-tests.nix` — Unit tests for lib functions using `assertTest` helper.
