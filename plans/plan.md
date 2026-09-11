# Marchyo Feature Roadmap — remaining work

> Derived from the omarchy↔marchyo gap analysis. The original 24-feature,
> dependency-ordered roadmap has fully shipped: the 2026-07 parity batch
> (PRs #104–#121), the unified runtime-first change model (runtime /
> `--apply` / `--revert` on every mutating CLI command, backed by
> `packages/marchyo-cli/packages/core/src/{runtime-state,apply}.ts` and
> `marchyo runtime restore`), the full CLI command surface (toggles,
> capture, menu/launchers, power/session, font, install/remove, webapp,
> security enrollment), and N-theme runtime switching
> (`marchyo.theme.themes` + `marchyo theme list/set/next` + `marchyo bg`).
> This file now tracks only what is left.

## F1.11 — Local AI integration (deferred)

- **Status:** `marchyo.ai.local.enable` is **declared but unimplemented** —
  enabling it currently fails an assertion (use OpenRouter instead).
- **Goal:** `marchyo.ai.local.enable` → `services.ollama` (with
  `acceleration = "cuda"|"rocm"` driven by `marchyo.graphics.vendors`),
  optional model pre-pull; expose the endpoint to shell/editor.
- **Files:** new `modules/nixos/ollama.nix`; option in
  `modules/nixos/options/ai.nix`.
- **Effort:** M. **Notes:** acceleration wiring should read graphics vendors
  so CUDA/ROCm is automatic.

## Follow-ups

- **Share upload target.** `marchyo share` stages clipboard/file/folder
  paths on the clipboard; an actual upload backend is still an open
  decision.
- **hyprlock live theme swap.** The runtime theme switch recolors ghostty,
  GTK, Hyprland, and the bar at runtime, but hyprlock (plus console and
  Plymouth) keeps the build-time theme until rebuild. A `source =` include
  in the hyprlock config would make it runtime-swappable.

## Out of scope (Nix subsumes or low value)

- omarchy's `update`/`migrate` engine, `omarchy-refresh-*`, AUR tooling →
  `nixos-rebuild` + `flake.lock` + generations already cover this.
- Dev-environment installers (mise Rails/Go/…) → per-project `nix develop`/devenv.
- Bespoke per-model kernel patches → expose kernel package choice, not patches.
- Windows VM → large, niche; defer unless requested.
