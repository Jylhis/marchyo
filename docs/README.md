# Marchyo contributor reference

Detailed system-architecture reference for people (and agents) working *on*
marchyo. This is the deep companion to the distilled [`AGENTS.md`](../AGENTS.md)
at the repo root — start there for the essentials, come here for the full detail.

Documentation is organized into two trees (mirroring the omarchy model):

- **`docs/`** (this tree) — contributor/system-architecture reference.
- **[`manual/`](../manual/)** — published end-user documentation (how to *use* marchyo).

## Contents

- [architecture.md](architecture.md) — project overview, thin-flake
  layout, module organization, flake outputs, key files.
- [adding-modules.md](adding-modules.md) — code style, module patterns
  (`mkIf`/`mkDefault`/`mkMerge`), how to add a module, cross-module data flow.
- [options-reference.md](options-reference.md) — the full `marchyo.*` option
  tables (feature flags, users, localization, theming, defaults, keyboard/IME,
  graphics, performance, desktop extras, dictation, launcher, web apps) and
  breaking changes.
- [gotchas.md](gotchas.md) — the accumulated sharp edges (theme source of truth,
  design system 6.0, font stack, the stylix retirement, the in-shell launcher, Plymouth
  generation, ghostty ssh, hyprlock fingerprint, …).
- [ci-and-testing.md](ci-and-testing.md) — commands, the test suite, CI pipeline,
  session-completion checklist.

The published user-facing docs live in [`site/`](../site/) (Astro + Starlight,
https://marchyo.org). Keep `site/src/content/docs/docs/configuration/` in sync
with the option declarations under `modules/nixos/options/`.

## Contributing

- Run `just fmt` before committing (CI enforces `nix fmt -- --ci`) and `just check` before finishing; `nix flake check` also builds the cheap checks. `nix flake show` lists the flake outputs.
- Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`.
- A new feature is a module under `modules/nixos/` or `modules/home/` (auto-discovered), its options under `modules/nixos/options/`, and a test predicate in `tests/eval/<feature>.nix`. See [adding-modules.md](adding-modules.md).
