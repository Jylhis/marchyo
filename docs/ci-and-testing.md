# Commands, testing & CI

## Commands

```bash
# Justfile recipes (preferred workflow)
just check               # Lint + eval checks (nix flake check --no-build, statix, deadnix)
just check-full          # nix flake check, then build every heavy check
just fmt                 # Format all Nix code (nixfmt, deadnix, statix, shellcheck, yamlfmt)
just build-nixos         # Build reference NixOS configuration (config: x86_64, aarch64)
just update              # nix flake update
just run                 # Run default configuration VM (x86_64-linux only)
just vm                  # Alias for just run

# Direct Nix commands
nix flake check          # Validate configuration and run all tests
nix fmt                  # Format all Nix code via treefmt-nix
nix flake show           # Display all flake outputs
nix eval .#checks.x86_64-linux --apply builtins.attrNames  # List available checks
nix build .#checks.x86_64-linux.ref-desktop                # Run one reference system's tests

# Development shell
nix develop              # Enter the dev shell (shell.nix; `nix-shell` works too)
```

`nix flake check` runs the default checks: evaluation tests, plus a few small builds (the shell JS/contract suites, the CLI theme-surface test, the xkbcli keymap check). The build-heavy checks are `legacyPackages.<system>.heavyChecks`, run by `just check-full` and the weekly CI job.

## Testing

`tests/` is organised around a few **reference systems** (`tests/lib.nix` `refBases`): NixOS configurations each evaluated once and shared by every test file. A test is a named predicate over one of them; each reference system is one check, `ref-<name>`, that runs all its predicates and names every failing one. The pinned systems (`minimal`, `headless`, `headless-dev`, `desktop`, `desktop-shell-off`, `desktop-dictation`, `full`, the graphics layouts) are the defaults for one kind of host; the tweak systems collect non-default settings from the test files (`refConfig`). Configurations no other test shares are `variant-<name>` checks, and every negative test (an assertion must fail) runs in the single `eval-assertions` check. Option-level tests use `helpers.evalOptions` and need no system. See `tests/README.md` for how to add a test.

- **Lib tests** (`tests/lib-tests.nix`): unit tests for lib functions using `assertTest` helper.
- **Heavy checks** (`legacyPackages.<system>.heavyChecks`): `hyprland --verify-config` over rendered configs, theme asset dir builds, both Plymouth theme variants (the only place the light variant's asset pipeline and `installCheckPhase` run), the `marchyo-shell` wrapper, the installer ISO evaluations, and the LocalSend Nautilus script.

### Quickshell shell tests (`tests/shell/`, Linux only)

The QML tree in `shell/` gets two headless suites, wired into `mkChecks`. Neither needs Quickshell or a Qt platform plugin — that is the point, since `just -f shell/Justfile check` (which loads the tree for real) can only run on a machine that has both:

- **`shell-format-unit`** — runs the pure-JS suites over `shell/Commons/*.js`: `format-test.js`, `notify-test.js`, `launcher-test.js`, and `peripherals-test.js`. Each `Commons/*.js` is a plain module with a CommonJS guard so QML imports it unchanged while Node can load it.
- **`shell-contracts`** — `bash tests/shell/contracts-test.sh`, static cross-file agreements that QML only resolves at runtime: qmldir completeness, `Bar/` widgets owning no `Process`/`Timer`/`Connections` (they are instantiated once per monitor), every `Services/` component being a singleton, every `Config.<tool>` being baked by `packages/marchyo-shell/package.nix`, and every shell IPC function name resolving to a function in `shell.qml`: each `shellIpc("<fn>")` call in the CLI sources (`modules/home/` reaches the shell only through `marchyo shell` verbs).

Both stage only the trees they read rather than the whole repo, so an unrelated `site/` or `docs/` edit does not rebuild them.

All changes must pass `just check` (or `nix flake check`).

## Session Completion

**When ending a work session**, complete ALL steps below. Work is NOT complete until changes are committed.

1. **Run quality gates** (if code changed) — `just check` and `just fmt`
2. **Verify** — All changes committed

## CI Pipeline

`.github/workflows/validate.yml` runs on push to `main`, PRs, manual dispatch and a weekly schedule:
1. **lint** — `nix fmt -- --ci` (formatting check) on a single `ubuntu-latest` runner (formatting is platform-independent).
2. **check** — `nix flake check --accept-flake-config` on `x86_64-linux` (every run) and `aarch64-linux` (not on PRs).
3. **build** — `nix build .#nixosConfigurations.x86_64.config.system.build.toplevel` (full system build, `ubuntu-latest` only, not on PRs, after `lint` and `check` succeed).
4. **heavy** — builds every `legacyPackages.x86_64-linux.heavyChecks` entry; weekly and on manual dispatch only.

Top-level `concurrency: ${{ github.workflow }}-${{ github.ref }}` cancels in-progress PR runs on new pushes (main runs are never canceled). Every job has a `timeout-minutes`.

`.github/workflows/site.yml` is a credential-free build gate for the Astro website (`site/`, landing page + Starlight docs): PRs and main pushes touching `site/**` run `bun run check` + `bun run build`. Deployment is handled outside GitHub Actions by the Cloudflare Workers Builds git integration (Worker `marchyo-site`, root directory `site`), which builds and deploys to https://marchyo.org on push to `main` — no repo secrets involved.

Uses [Cachix](https://app.cachix.org) (`jylhis` cache) to speed up builds. Dependabot groups all `nix` and `github-actions` bumps into single weekly PRs.
