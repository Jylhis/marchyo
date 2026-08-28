# Architecture

## Project Overview

Marchyo is a modular NixOS configuration flake providing curated system, Home Manager, nix-darwin, and nix-on-droid configurations with sensible defaults. It is distributed as a batteries-included Nix flake meant to be used as the sole input in downstream configurations: consumers build with the `marchyo.lib.mkNixosSystem` / `mkDarwinSystem` builders, which select the system-correct nixpkgs + home-manager + stylix automatically (x86_64-darwin → stable 26.05, everything else → unstable).

**Key features:**
- Modular architecture: configurations broken into small, manageable modules
- Feature flags: `marchyo.desktop.enable`, `marchyo.development.enable`, etc. enable entire stacks
- Home Manager integration for user-specific configurations and dotfiles
- nix-darwin support for macOS system configuration
- nix-on-droid support for an Android terminal environment (CLI-only), a first-class build target via `marchyo.lib.mkNixOnDroidConfiguration`
- Hardware support via `nixos-hardware` with NVIDIA/PRIME graphics options
- All custom options live under the `marchyo.*` namespace
- Multi-nixpkgs: the primary `nixpkgs` input is **unstable**; a separate `nixpkgs-stable` (nixos-26.05) backs `darwinConfigurations.x86_64` only. `home-manager`/`nix-darwin`/`stylix` track `master` to pair with unstable. A matching trio of release-26.05 inputs — `home-manager-stable`, `nix-darwin-stable`, `stylix-stable`, all following `nixpkgs-stable` — pairs with the stable set so `darwinConfigurations.x86_64` runs releases matching its nixpkgs (nix-darwin hard-fails the build on a release mismatch; home-manager and stylix warn). nix-on-droid is pinned independently (its own 2024-era nixpkgs + `home-manager-droid`).
- Nixpkgs passthrough: downstream consumers only need `inputs.marchyo`; `marchyo.lib.*` builders and `legacyPackages.<system>` give a system-correct nixpkgs (x86_64-darwin → stable 26.05)

## Hybrid Non-Flake + Flake Architecture

All real Nix logic lives in plain Nix files. `flake.nix` is a thin re-export wrapper that imports `outputs.nix` and forwards outputs. `default.nix` is a flake-compat shim for non-flake consumers (devenv, `nix-build`). Development uses `devenv.sh` (no experimental features required). `flake.lock` is the source of truth for input revisions; the devenv dev shell tracks the primary (unstable) `nixpkgs`, synchronized to `devenv.lock` via `just update`.

## Module Organization

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
docs/               # Contributor/system-architecture reference (this tree)
manual/             # Published end-user documentation (rendered by site/)
plans/              # Design RFCs for in-progress and proposed work
shell/              # Custom Quickshell shell QML tree (Phase 1 bar + Phase 2 OSD; see plans/shell.md)
modules/nixos/      # NixOS system-level modules (~31 modules)
modules/darwin/     # nix-darwin modules (imports shared options + generic modules)
modules/nix-on-droid/  # nix-on-droid (Android terminal): built via lib.mkNixOnDroidConfiguration; reuses generic git/shell modules; HM 24.05
modules/home/       # Home Manager user-level modules (~30 modules)
modules/generic/    # Shared modules imported by nixos, darwin, and home default.nix
packages/           # Custom Nix packages (hyprmon, plymouth-marchyo-theme)
tests/              # Evaluation-based test suite (no builds required)
site/               # Astro + Starlight website (landing page + docs, marchyo.org)
disko/              # Disk partitioning configurations (not wired into flake outputs)
installer/          # ISO build configs (not wired into flake outputs)
templates/workstation/  # Developer workstation template
```

## Flake Outputs

- `lib.mkNixosSystem` / `lib.mkDarwinSystem` — **Batteries-included system builders** (recommended consumer entry point). Take `{ system, modules ? [], specialArgs ? {} }` and auto-select the correct nixpkgs, home-manager, nix-darwin, stylix, overlay and marchyo modules via the `inputsFor` selector in `outputs.nix` (x86_64-darwin → stable 26.05 trio; everything else → unstable). The reference `nixosConfigurations`/`darwinConfigurations` are built through these same builders. Also exported: `lib.mkNixOnDroidConfiguration` (batteries-included nix-on-droid builder, fixed to aarch64-linux; flows through the `droidInputs` grouping the way the others flow through `inputsFor`), `lib.mkHomeConfiguration`, `lib.inputsFor`, `lib.mkPkgs`
- `nixosModules.default` — Main NixOS module (includes Home Manager, Stylix, overlay)
- `nixosModules.home-manager` — Re-exported home-manager NixOS module
- `darwinModules.default` — nix-darwin module (includes Home Manager, overlay)
- `homeManagerModules.default` — Home Manager module only
- `homeManagerModules._1password` — 1Password Home Manager module
- `overlays.default` — Nixpkgs overlay (darwin-safe: Linux packages wrapped in `optionalAttrs`)
- `packages.{linux}.hyprmon` — Hyprland monitor management tool
- `packages.{linux}.plymouth-marchyo-theme` — Plymouth boot splash theme
- `legacyPackages.{system}` — Full nixpkgs with overlay applied, **system-aware** (x86_64-darwin → stable nixos-26.05, every other system → unstable; via `inputsFor`/`mkPkgs`)
- `templates.workstation` — Starter workstation template (uses nixpkgs passthrough)
- `apps.x86_64-linux.default` — QEMU VM runner with all features enabled
- `checks.{linux}.*` — Evaluation test suite
- `formatter.{system}` — treefmt wrapper (shared config with devenv)
- `nixosModules` / `darwinModules` / `homeManagerModules` / `nixOnDroidModules` — per-platform module sets
- `nixosConfigurations.{x86_64,aarch64}` — Reference NixOS configs (Linux, unstable), built through `lib.mkNixosSystem`; `x86_64` is built by CI and backs the VM runner
- `darwinConfigurations.{aarch64,x86_64}` — Reference nix-darwin configs, built through `lib.mkDarwinSystem`. `aarch64` rides unstable (`nix-darwin.lib.darwinSystem`, `home-manager`/`stylix` master); `x86_64` is pinned by the builder to stable nixos-26.05 (the builder injects `nixpkgs.pkgs = mkPkgs "x86_64-darwin"` + `mkForce`-cleared `nixpkgs.config`/`overlays`), uses `nix-darwin-stable.lib.darwinSystem` (nix-darwin-26.05) plus `home-manager-stable` + `stylix-stable` (both release-26.05) — all three perform a nixpkgs-release check (nix-darwin hard-fails, the others warn). `mkDarwinSystem` selects the matching nix-darwin/HM/stylix per system via the `inputsFor` selector and the `mkDarwinModules <hmModule>` helper, so each config bakes in the HM matching its nixpkgs
- `homeConfigurations.{x86_64-linux,aarch64-linux}` — Standalone Home Manager configs (Linux only)
- `nixOnDroidConfigurations.aarch64` — Reference Android terminal config, built through `lib.mkNixOnDroidConfiguration` (the same exported builder consumers use). Built impurely (`nix build --impure …activationPackage`): nix-on-droid uses `builtins.storePath`, so it cannot be evaluated in pure `nix flake check`. Coverage instead comes from `tests/eval/nix-on-droid.nix`, a pure check of the droid Home-Manager module (incl. the reused generic modules) against HM 24.05

Downstream consumers build with `marchyo.lib.mkNixosSystem` / `mkDarwinSystem`, which select the system-correct nixpkgs automatically — no separate nixpkgs input needed. The raw `marchyo.inputs.nixpkgs` passthrough remains available but is always **unstable**; for a system-correct, overlay-applied package set use `marchyo.legacyPackages.<system>`.

## Key Files

- `flake.nix` — Flake entry point. Imports `outputs.nix` with flake inputs, wraps per-system outputs with `forAllSystems`. Includes `flake-compat` as a non-flake input.
- `flake.lock` — **Single source of truth** for all pinned input revisions (nixpkgs, home-manager, stylix, etc.). `devenv.lock` syncs to this via `just update`.
- `outputs.nix` — All output logic. Takes `{ inputs }:`, returns nixosModules, darwinModules, homeManagerModules, overlays, templates, nixosConfigurations, the `lib` builders (`mkNixosSystem`/`mkDarwinSystem` via the `inputsFor` per-system selector + `mkPkgs`), and per-system constructors (mkPackages, mkChecks, mkFormatter, mkApps, legacyPackages).
- `default.nix` — Flake-compat shim. Uses `flake-compat` (pinned in `flake.lock`) to expose flake outputs to non-flake consumers (`nix-build`, devenv).
- `overlay.nix` — Nixpkgs overlay. Takes `{ inputs }:`, returns `final: prev:` function. All packages are Linux-only (wrapped in `lib.optionalAttrs stdenv.isLinux`).
- `lib/systems.nix` — Single source of truth for the system list. `flake.nix` imports `{ linux, darwin, all }` from here; adding/removing a system is a one-file change.
- `lib/discover-modules.nix` — Auto-discovery helper. Returns every `.nix` file directly under a given directory (excluding `default.nix`) plus any subdirectory containing `default.nix`. Used by `modules/{nixos,home}/default.nix` and `modules/nixos/options/default.nix`.
- `modules/nixos/options/` — `marchyo.*` option declarations split by namespace (users, defaults, feature-flags, performance, graphics, localization, theme, keyboard, deprecated). The directory's `default.nix` auto-imports every file.
- `modules/nixos/default.nix` — Auto-discovers every NixOS module via `lib/discover-modules.nix`. Module merging is order-independent at the option/config layer; use `mkBefore`/`mkAfter`/priorities if a specific merge order matters.
- `modules/darwin/default.nix` — **Manual** import list for nix-darwin modules. Curated subset (Wayland/systemd/desktop modules are NixOS-only and intentionally excluded). Imports `../nixos/options` for the shared option namespace.
- `modules/home/default.nix` — Auto-discovers every Home Manager module via `lib/discover-modules.nix`.
- `tests/default.nix` — Test suite entry point. Auto-discovers every file in `tests/eval/` and merges the attrsets they return; appends `lib-tests.nix`.
- `tests/lib.nix` — Shared test helpers (`testNixOS`, `withTestUser`, `minimalConfig`).
- `tests/eval/*.nix` — Per-feature evaluation tests. Each file receives helpers + `lib`/`pkgs`/`nixosModules`/`homeManagerModules` and returns an attrset of named tests.
- `tests/lib-tests.nix` — Unit tests for lib functions using `assertTest` helper.
