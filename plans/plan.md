# Marchyo Feature Roadmap — remaining work

Tracks the feature work that is still open. Everything not listed here is
implemented in the flake.

## F1.11 — Local AI integration (deferred)

- **Status:** not started — no `marchyo.ai.*` options are declared at all
  (an earlier revision of this note claimed the option existed and failed an
  assertion; that was stale).
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
- **hyprlock live theme swap. DONE** (a797211): the shell-off lock surface
  sources `current-theme/hyprlock-colors.conf`. Console/TTY followed
  (38898a8, best-effort live + next-boot). Plymouth stays build-time by
  design: it is never on screen during a session, so runtime theming has
  no meaning for it (THEME-RUNTIME-REVIEW.md §1).

## Out of scope (Nix subsumes or low value)

- omarchy's `update`/`migrate` engine, `omarchy-refresh-*`, AUR tooling →
  `nixos-rebuild` + `flake.lock` + generations already cover this.
- Dev-environment installers (mise Rails/Go/…) → per-project `nix develop`/devenv.
- Bespoke per-model kernel patches → expose kernel package choice, not patches.
- Windows VM → large, niche; defer unless requested.
