# Commands, testing & CI

## Commands

```bash
# Justfile recipes (preferred workflow)
just check               # Lint + eval checks (nix flake check, statix, deadnix)
just fmt                 # Format all Nix code (nixfmt, deadnix, statix, shellcheck, yamlfmt)
just build-nixos         # Build reference NixOS configuration (config: x86_64, aarch64)
just build-darwin        # Build reference nix-darwin configuration
just build-nix-on-droid  # Build reference Android config (uses --impure; nix-on-droid needs builtins.storePath)
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

There is no way to run a single test in isolation; `nix flake check` runs them all (fast evaluation-only checks, plus one small real build: the `build-plymouth-theme-{dark,light}` theme checks).

## Testing

Tests in `tests/` are fast evaluation-based checks (no builds required). Two categories:
- **Module tests** (`tests/eval/*.nix`, auto-discovered): verify NixOS configs evaluate without errors for various feature combinations (minimal/feature-flags, themes, keyboard, graphics, defaults, hyprland config check).
- **Lib tests** (`tests/lib-tests.nix`): unit tests for lib functions using `assertTest` helper.

One deliberate exception to eval-only: the `build-plymouth-theme-{dark,light}` checks (added in `outputs.nix`'s `mkChecks`, Linux only) actually build the tiny Plymouth theme package in both variants, running its asset pipeline and `installCheckPhase`.

### Quickshell shell tests (`tests/shell/`, Linux only)

The QML tree in `shell/` gets two headless suites, wired into `mkChecks` alongside the Plymouth ones. Neither needs Quickshell or a Qt platform plugin — that is the point, since `just -f shell/Justfile check` (which loads the tree for real) can only run on a machine that has both:

- **`shell-format-unit`** — `node tests/shell/format-test.js`, unit tests for `shell/Commons/Format.js`, the shell's pure parsing logic. It is a plain `.js` module with a CommonJS guard so QML imports it unchanged while Node can load it.
- **`shell-contracts`** — `bash tests/shell/contracts-test.sh`, static cross-file agreements that QML only resolves at runtime: qmldir completeness, `Bar/` widgets owning no `Process`/`Timer`/`Connections` (they are instantiated once per monitor), every `Services/` component being a singleton, every `Config.<tool>` being baked by `packages/marchyo-shell/package.nix`, and every `marchyo-shell ipc … -- shell <fn>` call in `modules/home/` resolving to a function in `shell.qml`.

Both stage only the trees they read rather than the whole repo, so an unrelated `site/` or `docs/` edit does not rebuild them. Background and rationale: [`plans/shell-research.md`](../plans/shell-research.md).

All changes must pass `just check` (or `nix flake check`).

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

`.github/workflows/site.yml` is a credential-free build gate for the Astro website (`site/`, landing page + Starlight docs): PRs and main pushes touching `site/**` run `bun run check` + `bun run build`. Deployment is handled outside GitHub Actions by the Cloudflare Workers Builds git integration (Worker `marchyo-site`, root directory `site`), which builds and deploys to https://marchyo.org on push to `main` — no repo secrets involved.

Uses [Cachix](https://app.cachix.org) (`jylhis` cache) to speed up builds. Dependabot groups all `nix` and `github-actions` bumps into single weekly PRs.
