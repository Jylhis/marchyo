# Marchyo Feature Roadmap — remaining work

Tracks the feature work that is still open. Everything not listed here is
implemented in the flake.

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
- **hyprlock live theme swap.** With the shell on, the lock surface is now
  the in-shell `WlSessionLock` (`shell/Lock/`), which binds `Color.*` and so
  already follows `marchyo theme set` live. Only the shell-off path
  (hyprlock, plus console and Plymouth) keeps the build-time theme until
  rebuild; a `source =` include in the hyprlock config would make hyprlock
  runtime-swappable there.

## Out of scope (Nix subsumes or low value)

- omarchy's `update`/`migrate` engine, `omarchy-refresh-*`, AUR tooling →
  `nixos-rebuild` + `flake.lock` + generations already cover this.
- Dev-environment installers (mise Rails/Go/…) → per-project `nix develop`/devenv.
- Bespoke per-model kernel patches → expose kernel package choice, not patches.
- Windows VM → large, niche; defer unless requested.
