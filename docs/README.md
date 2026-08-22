# Marchyo contributor reference

Detailed system-architecture reference for people (and agents) working *on*
marchyo. This is the deep companion to the distilled [`AGENTS.md`](../AGENTS.md)
at the repo root — start there for the essentials, come here for the full detail.

Documentation is organized into three trees (mirroring the omarchy model):

- **`docs/`** (this tree) — contributor/system-architecture reference.
- **[`manual/`](../manual/)** — published end-user documentation (how to *use* marchyo).
- **[`plans/`](../plans/)** — design RFCs for in-progress and proposed work.

## Contents

- [architecture.md](architecture.md) — project overview, hybrid non-flake/flake
  layout, module organization, flake outputs, key files.
- [adding-modules.md](adding-modules.md) — code style, module patterns
  (`mkIf`/`mkDefault`/`mkMerge`), how to add a module, cross-module data flow.
- [options-reference.md](options-reference.md) — the full `marchyo.*` option
  tables (feature flags, users, localization, theming, defaults, keyboard/IME,
  graphics, performance, AI, desktop extras, dictation, launcher, web apps) and
  breaking changes.
- [gotchas.md](gotchas.md) — the accumulated sharp edges (theme source of truth,
  design-system v2, font stack, Stylix disablement, the Vicinae gotchas, Plymouth
  generation, nix-on-droid, ghostty ssh, hyprlock fingerprint, …).
- [ci-and-testing.md](ci-and-testing.md) — commands, the test suite, CI pipeline,
  session-completion checklist.

The published user-facing docs live in [`site/`](../site/) (Astro + Starlight,
https://marchyo.org). Keep `site/src/content/docs/docs/configuration/` in sync
with the option declarations under `modules/nixos/options/`.
