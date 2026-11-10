# Architecture

## Project Overview

Marchyo is a modular NixOS configuration flake providing curated system, and Home Manager configurations with sensible defaults. It is distributed as a batteries-included Nix flake meant to be used as the sole input in downstream configurations: consumers build with the `marchyo.lib.mkNixosSystem` builder, which selects the system-correct nixpkgs + home-manager automatically.

**Key features:**
- Modular architecture: configurations broken into small, manageable modules
- Feature flags: `marchyo.desktop.enable`, `marchyo.development.enable`, etc. enable entire stacks
- Home Manager integration for user-specific configurations and dotfiles
- Hardware support through NVIDIA/PRIME graphics options; hosts import `nixos-hardware` profiles from their own flake
- All custom options live under the `marchyo.*` namespace
- Multi-nixpkgs: the primary `nixpkgs` input is **unstable**; `home-manager` tracks `master` to pair with unstable.
- Nixpkgs passthrough: downstream consumers only need `inputs.marchyo`; `marchyo.lib.*` builders and `legacyPackages.<system>` give a system-correct nixpkgs

## Plain Nix Behind a Thin Flake

All real Nix logic lives in plain Nix files. `flake.nix` is a thin re-export wrapper that imports `outputs.nix` and forwards outputs. The dev shell is `shell.nix`, exposed as `devShells.<system>.default` and usable with plain `nix-shell`. `flake.lock` is the only source of input revisions; `shell.nix` reads its `nixpkgs` and `treefmt-nix` pins when run without flakes.

## Flake Inputs

| Input | Purpose |
|-------|---------|
| `nixpkgs` | Primary package set — NixOS unstable channel |
| `home-manager` | User environment management (master, pairs with unstable) |
| `treefmt-nix` | Multi-tool code formatter |
| `ncro` | Nix Cache Route Optimizer (`services.ncro.enable`, on by default) |
| `tinted-schemes` | Base16 scheme catalog, read at eval time (non-flake input) |
| `disko` | Declarative partitioning for the `disko/` layouts |

Every input that takes a nixpkgs follows the root `nixpkgs`.

## Module Organization

```
flake.nix           # Flake entry point — imports outputs.nix, wraps per-system outputs
flake.lock          # Single source of truth for all pinned inputs (nixpkgs, home-manager, etc.)
outputs.nix         # All output logic — takes { inputs }, returns modules, packages, checks, etc.
overlay.nix         # Nixpkgs overlay (marchyo-cli/-shell/-wallpapers, plymouth-marchyo-theme, plus the vendored design system in lib/design)
treefmt.nix         # Formatter config for treefmt-nix
shell.nix           # Development shell (nix develop / nix-shell)
Justfile            # Task runner (check, fmt, build, update, verify)
statix.toml         # Statix linter configuration
docs/               # Contributor/system-architecture reference (this tree)
manual/             # Published end-user documentation (rendered by site/)
shell/              # Quickshell shell QML tree, the default desktop shell (bar, launcher, OSD, panels, notifications, lock; see shell/README.md)
modules/nixos/      # NixOS system-level modules (auto-discovered)
modules/home/       # Home Manager user-level modules (auto-discovered)
modules/generic/    # Shared helpers (palette, base16 slots, keyboard lib) imported by path
packages/           # Custom Nix packages (marchyo-cli, marchyo-shell, plymouth-marchyo-theme, marchyo-wallpapers)
tests/              # Evaluation-based test suite (no builds required)
site/               # Astro + Starlight website (landing page + docs, marchyo.org)
disko/              # Disk layouts, exported as lib.diskoLayout (+ nixosModules.disko)
installer/          # Installer ISOs, exported as packages.x86_64-linux.iso-{minimal,graphical}
templates/workstation/  # Developer workstation template
```

## Flake Outputs

- `lib.mkNixosSystem` — **Batteries-included system builder** (recommended consumer entry point). Take `{ system, modules ? [], specialArgs ? {} }` and wire in marchyo's nixpkgs, home-manager, overlay and modules. The reference `nixosConfigurations` are built through this same builder. Also exported: `lib.mkPkgs`
- `nixosModules.default` — Main NixOS module (includes Home Manager, overlay)
- `nixosModules.home-manager` — Re-exported home-manager NixOS module
- `nixosModules.disko` — Re-exported disko NixOS module; pair with `lib.diskoLayout "<layout>" { device = …; }` (layouts in `lib.diskoLayouts`)
- `packages.x86_64-linux.iso-{minimal,graphical}` — Installer ISOs from `installer/`
- `homeManagerModules.default` — The Home Manager modules (`modules/home`); `modules/nixos/system.nix` imports them for every `marchyo.users` entry. They read `osConfig.marchyo.*` directly, so they need the NixOS module
- `homeManagerModules._1password` — 1Password Home Manager module
- `overlays.default` — Nixpkgs overlay (Linux packages wrapped in `optionalAttrs`)
- `packages.{system}.{marchyo-cli,marchyo-wallpapers,marchyo-shell,plymouth-marchyo-theme}` — marchyo packages
- `legacyPackages.{system}` — Full nixpkgs with overlay applied (via `mkPkgs`)
- `templates.workstation` — Starter workstation template (uses nixpkgs passthrough)
- `apps.x86_64-linux.default` — QEMU VM runner with all features enabled
- `checks.{system}.*` — Evaluation test suite
- `formatter.{system}` — treefmt wrapper (same config as the dev shell)
- `devShells.{system}.default` — the dev shell from `shell.nix`
- `nixosModules` / `homeManagerModules` — per-platform module sets
- `nixosConfigurations.{x86_64,aarch64}` — Reference NixOS configs (Linux, unstable), built through `lib.mkNixosSystem`; `x86_64` is built by CI and backs the VM runner

Downstream consumers build with `marchyo.lib.mkNixosSystem`, which brings marchyo's nixpkgs — no separate nixpkgs input needed. For an overlay-applied package set use `marchyo.legacyPackages.<system>`.

## Key Files

- `flake.nix` — Flake entry point. Imports `outputs.nix` with flake inputs, wraps per-system outputs with `forAllSystems`.
- `flake.lock` — **Single source of truth** for all pinned input revisions (nixpkgs, home-manager, etc.).
- `outputs.nix` — All output logic. Takes `{ inputs }:`, returns nixosModules, homeManagerModules, overlays, templates, nixosConfigurations, the `lib` builders (`mkNixosSystem`, `mkPkgs`), and per-system constructors (mkPackages, mkChecks, mkFormatter, mkApps, legacyPackages; the latter also carries `heavyChecks` and `testPredicates`).
- `overlay.nix` — Nixpkgs overlay. Takes `{ inputs }:`, returns `final: prev:` function. `marchyo-cli`/`marchyo-wallpapers` are cross-platform; Linux-only packages are wrapped in `lib.optionalAttrs stdenv.isLinux`.
- `lib/systems.nix` — Single source of truth for the system list. `flake.nix` imports `linux` from here; adding/removing a system is a one-file change.
- `lib/discover-modules.nix` — Auto-discovery helper. Returns every `.nix` file directly under a given directory (excluding `default.nix`) plus any subdirectory containing `default.nix`. Used by `modules/{nixos,home}/default.nix` and `modules/nixos/options/default.nix`.
- `modules/nixos/options/` — `marchyo.*` option declarations, one file per namespace (feature-flags, users, localization, theme, keyboard, graphics, defaults, and many more). The directory's `default.nix` auto-imports every file, so adding a namespace is a one-file change.
- `modules/nixos/default.nix` — Auto-discovers every NixOS module via `lib/discover-modules.nix`. Module merging is order-independent at the option/config layer; use `mkBefore`/`mkAfter`/priorities if a specific merge order matters.
- `modules/home/default.nix` — Auto-discovers every Home Manager module via `lib/discover-modules.nix`.
- `tests/default.nix` — Test suite entry point. Auto-discovers every file in `tests/eval/`, evaluates each shared reference system once (its base from `tests/lib.nix` plus the files' `refConfig` modules), and turns each system's predicates into one `ref-<name>` check; also the `variant-*` checks, `eval-assertions` and the heavy checks. Merges throw on duplicate names (`lib/merge-unique.nix`).
- `tests/lib.nix` — The test harness (`mkSystem`, `evalOptions`, `predicateCheck`, `assertionCheck`), the reference and failing system bases, and helpers (`withTestUser`, `desktopWith`, `minimalConfig`, `expect`).
- `tests/eval/*.nix` — Per-feature tests. Each file receives helpers + `lib`/`pkgs`/module sets and returns predicates on reference systems (`refs`), their settings (`refConfig`), `variants`, negative tests (`failing`), and standalone or heavy checks.
- `tests/lib-tests.nix` — Unit tests for lib functions using `assertTest` helper.
