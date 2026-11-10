# Agent Instructions

Tool-agnostic guidance for AI agents working in this repository. This file is the distilled source of truth for the essentials; the [`docs/`](docs/) contributor tree holds the full detailed reference (architecture, flake outputs, options tables, gotchas, CI/testing) — start at [docs/README.md](docs/README.md).

## What this repository is

Marchyo is a modular NixOS configuration flake with Home Manager support. Consumers build systems with `marchyo.lib.mkNixosSystem`; all custom options live under the `marchyo.*` namespace. All real logic lives in plain Nix files — `flake.nix` is a thin wrapper around `outputs.nix`, and `flake.lock` is the single source of truth for input revisions. `shell/` is the QML/Quickshell desktop shell, `packages/marchyo-cli/` is a Bun/TypeScript workspace, and `site/` is the Astro/Starlight website. The site deploys from the Jylhis/marchyo projection, which has no `lib/design`, so it imports a tracked copy in `site/vendor/design`; update that copy by hand after a design change.

## Declarative only — never suggest imperative changes

This is a declarative NixOS configuration. Never suggest imperative package installs or ad-hoc system mutation (`nix-env -i`, `nix profile install`, `apt`, `pip install --user`, editing dotfiles in `$HOME` by hand, `systemctl enable` on the host). The correct change is always: edit the Nix modules in this repo, then rebuild (`nixos-rebuild switch` or the reference builds below). If a package or service is missing, add it to the appropriate module.

## Development and essential commands

Enter the dev shell with `nix develop` (or `nix-shell`; both read `shell.nix`, pinned by `flake.lock`). It provides Nix tooling, `just`, `jq`, Bun, Node.js, the CLI, and Qt QML tools, and configures `QML_IMPORT_PATH` for `qs.*` imports.

```bash
just check               # Linux: nix flake check --no-build, then statix + deadnix
just check-full          # nix flake check, then build every heavy check
just fmt                 # nix fmt via treefmt
just build-nixos         # reference NixOS config; optional config=x86_64|aarch64
just cli-test            # frozen Bun install, typecheck, and unit tests
just site-build          # npm ci, Astro check, and build
just -f shell/Justfile check  # live offscreen QML harness; Linux/Wayland host only
```

`just check` is the fast local gate and deliberately passes `--no-build`. Run plain `nix flake check` when the check derivations must be built, and `just check-full` after changes the heavy checks cover (Hyprland config rendering, theme assets, Plymouth, the shell wrapper, the ISOs). `just update` runs `nix flake update`.

## Adding or removing modules

- `modules/nixos/` and `modules/home/` are **auto-discovered** via `lib/discover-modules.nix`: every `.nix` file in the directory (plus any subdirectory containing a `default.nix`) is imported automatically. Adding or removing a module is a one-file change — never edit an import list for these.
- `modules/generic/` holds helpers (palette, base16 slots, keyboard lib) that nixos and home modules import by path; it is not auto-imported.
- Option declarations go in `modules/nixos/options/` (one file per logical namespace, auto-discovered), declaring `options.marchyo.<namespace>`.

## The `marchyo.*` flag model

Features are gated behind enable flags: `marchyo.desktop.enable`, `marchyo.development.enable`, `marchyo.media.enable`, `marchyo.office.enable`, plus per-feature namespaces (`marchyo.dictation`, `marchyo.webapps`, `marchyo.theme`, `marchyo.keyboard`, `marchyo.graphics`, `marchyo.defaults`, …). Umbrella flags cascade: e.g. `desktop.enable = true` auto-enables `office`/`media` via `lib.mkDefault` so consumers can still override. Follow this pattern for new features: an enable flag in `modules/nixos/options/`, implementation gated with `lib.mkIf`, cascaded defaults set with `lib.mkDefault`.

## Module conventions (mkIf / mkDefault)

- Gate feature config with `config = lib.mkIf cfg.feature.enable { ... };`, never `if/then/else` around config attrsets.
- Use `lib.mkDefault` for defaults downstream configurations can override; use `lib.mkMerge` to combine multiple `mkIf` branches.
- Home Manager modules read NixOS config via optional `{ osConfig ? {}, ... }` and `osConfig.marchyo or {}`.

## Testing

- `tests/eval/*.nix` is auto-discovered. A test is a named predicate (`config -> true | false | message | [ messages ]`) over one of the shared reference systems in `tests/lib.nix` (`refBases`), each evaluated once and run as one check, `ref-<name>`, that names every failing predicate. Add `refs.<ref>.<test>` to the system that already has the configuration you need; non-default settings go on a tweak system through `refConfig.<ref>` from the same file. Negative tests go in `failing` (run together in `eval-assertions`), one-off configurations in `variants`, build checks in `heavy`. Every new module or option needs a predicate. See `tests/README.md`.
- `tests/lib-tests.nix` contains unit tests for lib functions using `assertTest`.
- The default checks also run `tests/shell/*-test.js`, `tests/shell/contracts-test.sh` and `tests/cli/theme-surfaces-test.js`. The heavy checks (`legacyPackages.<system>.heavyChecks`, `just check-full`, weekly CI) build both Plymouth variants, the Marchyo shell wrapper, the theme asset dirs, the `hyprland --verify-config` runs and the ISO evaluations. HM modules read `osConfig.marchyo.*` directly (no `or` fallbacks) and are exercised only through NixOS configs; there is no standalone Home Manager output.

## QML shell pitfalls

- `Bar/` widgets are instantiated per monitor: seat-global state, processes, and timers belong in singleton components under `Services/`; keep each directory's `qmldir` complete.
- `Commons/Colors.qml`, `Style.qml`, and `Config.qml` are usable source defaults but the Nix package regenerates them with theme values and store paths; change the generators in `packages/marchyo-shell/package.nix` when changing baked output.
- Run QML tools inside the dev shell; its `.dev/qml-modules/qs` alias is required because qmlls' Quickshell mirror lacks `qmldir` files.
- To check a QML change on screen, run `shell/dev/shot SURFACE` from the dev shell. It runs the
  tree's shell in an isolated nested Hyprland and never touches the live session or the
  `marchyo-shell` service.
- `shell/dev/sandbox down` stops the sandbox and every process it started.
- Never start Hyprland without a parent `WAYLAND_DISPLAY`: it takes the DRM seat and aborts.
- Never use `pkill -f` to stop sandbox processes; it can match live session processes.

## Formatting and commits

- Run `just fmt` before committing — CI enforces `nix fmt -- --ci`. Treefmt runs nixfmt, deadnix, statix, shellcheck, yamlfmt, typos, actionlint, qmlformat, and Linux-only qmllint.
- Use conventional commit messages: `feat:`, `fix:`, `docs:`, `chore:`, etc.
- All changes must pass `just check` before a session is complete, and work is not done until it is committed.
- Keep `site/src/content/docs/docs/configuration/` in sync when changing options under `modules/nixos/options/`.
- Docs and code comments describe the current state only: no history (what changed, what was replaced, commit refs) and no backstory or motivation. Git holds history.

## New theme surfaces

- Emit the surface from the single palette source in all three places that build a theme dir:
  `theme-runtime.nix` (Jylhis pair), its `mkSchemeThemeDir` (catalog/inline), and the CLI
  `generateThemeChangeBase` (matugen); the relink/reload leg goes in `activateThemeDir`.
- Stay IFD-free: pure string templating from `palette.hex` / base16 slots, never `readFile` of
  a built derivation such as `pkgs.jylhis-themes` (referencing it as a path is fine).
- Add a predicate in `tests/eval/themes.nix` and update
  `site/src/content/docs/docs/configuration/theming.mdx`.
- If a surface needs a role with no palette token, report it as a `pkgs.jylhis-design-src`
  gap instead of inventing it locally.
