# Agent Instructions

Tool-agnostic guidance for AI agents working in this repository. This file is the
distilled source of truth for the essentials; [CLAUDE.md](CLAUDE.md) holds the full
detailed reference (architecture, flake outputs, options tables, gotchas).

## What this repository is

Marchyo is a modular NixOS configuration flake with Home Manager, nix-darwin, and
nix-on-droid support. Consumers build systems with `marchyo.lib.mkNixosSystem` /
`mkDarwinSystem` / `mkNixOnDroidConfiguration`; all custom options live under the
`marchyo.*` namespace. All real logic lives in plain Nix files — `flake.nix` is a
thin wrapper around `outputs.nix`, and `flake.lock` is the single source of truth
for input revisions.

## Declarative only — never suggest imperative changes

This is a declarative NixOS configuration. Never suggest imperative package
installs or ad-hoc system mutation (`nix-env -i`, `nix profile install`, `apt`,
`pip install --user`, editing dotfiles in `$HOME` by hand, `systemctl enable` on
the host). The correct change is always: edit the Nix modules in this repo, then
rebuild (`nixos-rebuild switch`, `darwin-rebuild switch`, or the reference builds
below). If a package or service is missing, add it to the appropriate module.

## Essential commands

```bash
just check               # Lint + eval checks (nix flake check, statix, deadnix)
just fmt                 # Format all Nix code (nixfmt, deadnix, statix, shellcheck, yamlfmt)
just build-nixos         # Build reference NixOS configuration
just build-darwin        # Build reference nix-darwin configuration
just build-nix-on-droid  # Build reference Android config (needs --impure; the recipe handles it)
```

There is no single-test runner; `nix flake check` runs all tests (fast,
evaluation-only — no builds).

## Adding or removing modules

- `modules/nixos/` and `modules/home/` are **auto-discovered** via
  `lib/discover-modules.nix`: every `.nix` file in the directory (plus any
  subdirectory containing a `default.nix`) is imported automatically. Adding or
  removing a module is a one-file change — never edit an import list for these.
- `modules/darwin/default.nix` is a **hand-curated** import list (darwin-safe
  subset; Wayland/systemd/desktop modules are NixOS-only). Add imports there
  manually, and keep it curated.
- `modules/generic/` holds modules shared by nixos, darwin, and home.
- `modules/nix-on-droid/` is a small separate tree on HM 24.05 — do not import
  `modules/home/*`, `modules/nixos/options`, or the overlay there.
- Option declarations go in `modules/nixos/options/` (one file per logical
  namespace, auto-discovered), declaring `options.marchyo.<namespace>`.

## The `marchyo.*` flag model

Features are gated behind enable flags: `marchyo.desktop.enable`,
`marchyo.development.enable`, `marchyo.media.enable`, `marchyo.office.enable`,
plus per-feature namespaces (`marchyo.ai`, `marchyo.dictation`,
`marchyo.webapps`, `marchyo.tracking`, `marchyo.theme`, `marchyo.keyboard`,
`marchyo.graphics`, `marchyo.defaults`, …). Umbrella flags cascade: e.g.
`desktop.enable = true` auto-enables `office`/`media` via `lib.mkDefault` so
consumers can still override. Follow this pattern for new features: an enable
flag in `modules/nixos/options/`, implementation gated with `lib.mkIf`, cascaded
defaults set with `lib.mkDefault`.

## Module conventions (mkIf / mkDefault)

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

- `lib.mkIf condition { ... }` — conditionally include a config block. Use for
  feature-gated sections (never `if/then/else` around config attrsets).
- `lib.mkDefault value` — set a value consumers can override. Use for any
  default that downstream configurations should be able to change.
- `lib.mkMerge [ ... ]` — combine multiple `mkIf` branches in one module.
- Home Manager modules read NixOS config via `osConfig` (declare it optional:
  `{ config, lib, osConfig ? {}, ... }:` and access `osConfig.marchyo or {}`).

## Darwin eval gate — keep option declarations platform-neutral

`modules/darwin/default.nix` imports the **shared** option namespace
`modules/nixos/options/`, and CI evaluates nix-darwin configurations on Linux
(`tests/eval/shell.nix` via `lib.mkDarwinSystem`). Therefore every file under
`modules/nixos/options/` is evaluated on darwin: option declarations must stay
platform-neutral — no Linux-only package references, NixOS-module imports, or
Linux-specific `types`/defaults in declarations. Put platform-specific behavior
in the implementation modules (which darwin simply doesn't import), not in the
options. The overlay follows the same rule: Linux-only packages are wrapped in
`lib.optionalAttrs stdenv.isLinux`.

## Testing

Tests are fast evaluation-based checks in `tests/`, run by `nix flake check`:

- `tests/eval/*.nix` — per-feature module tests, auto-discovered. Each file gets
  helpers + `lib`/`pkgs`/`nixosModules`/`homeManagerModules` and returns an
  attrset of named tests.
- `tests/lib-tests.nix` — unit tests for lib functions (`assertTest` helper).

Every new module or option needs an eval test:

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

`testNixOS` evaluates a full NixOS config without building; `withTestUser`
merges in a minimal bootable config. There are no standalone Home Manager
tests — HM modules are exercised through the NixOS configs.

## Formatting and commits

- Run `just fmt` (or `nix fmt`) before committing — mandatory, CI enforces it.
  It runs nixfmt, deadnix, statix, shellcheck, and yamlfmt via treefmt.
- Use conventional commit messages: `feat:`, `fix:`, `docs:`, `chore:`, etc.
- All changes must pass `just check` before a session is complete, and work is
  not done until it is committed.
- Keep the website docs (`site/src/content/docs/docs/configuration/`) in sync
  when changing options under `modules/nixos/options/`.
