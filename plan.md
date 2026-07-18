# Marchyo Feature Roadmap — Omarchy Parity & Beyond

> Derived from the omarchy↔marchyo gap analysis. Originally 24 features in
> dependency-ordered phases; **most have shipped** (see Completed below).
> This file now tracks only the remaining work. Each remaining item lists
> **goal · mechanism · files · effort · notes**.

## Completed (2026-07-18 batch — PRs #104–#121)

| Item | Feature | PR |
|------|---------|----|
| F0.1 | AGENTS.md as tool-agnostic SOT, CLAUDE.md imports it | [#109](https://github.com/Jylhis/marchyo/pull/109) |
| F0.2 | nixos-hardware re-export (`nixosModules.hardware.<profile>`) | [#114](https://github.com/Jylhis/marchyo/pull/114) |
| F0.3 | Option namespace scaffolds (landed per-feature: security, services, power, screensaver, menus, utilities, osd, tailscale; `brand.nix` dropped — plymouth/theme already cover it) | — |
| F1.1 | Firewall gate (`marchyo.security.firewall.enable`) | [#117](https://github.com/Jylhis/marchyo/pull/117) |
| F1.2 | Tailscale toggle (`marchyo.services.tailscale.enable`) | [#105](https://github.com/Jylhis/marchyo/pull/105) |
| F1.3 | Kernel selection (`marchyo.performance.kernel`); zram pre-existing | [#112](https://github.com/Jylhis/marchyo/pull/112) |
| F1.4 | Vulkan/ROCm hardware-accel completeness pass | [#112](https://github.com/Jylhis/marchyo/pull/112) |
| F1.5 | Hibernation (`marchyo.power.hibernation.*`, hypridle wiring, swap sizing) | [#108](https://github.com/Jylhis/marchyo/pull/108) |
| F1.6 | FIDO2 + fingerprint (`marchyo.security.{fido2,fingerprint}.enable`) | [#117](https://github.com/Jylhis/marchyo/pull/117) |
| F1.7 | btrfs subvolume alignment (`disko/btrfs.nix` = luks scheme, D2 resolved); snapper pre-existing | [#104](https://github.com/Jylhis/marchyo/pull/104) |
| F1.8 | LocalSend gate (`marchyo.services.localsend.enable`) | [#106](https://github.com/Jylhis/marchyo/pull/106) |
| F1.9 | Web apps — declarative `.desktop` + binds (pre-existing), parity round-out | [#116](https://github.com/Jylhis/marchyo/pull/116) |
| F1.10 | AI tooling (OpenRouter BYOK) — pre-existing | — |
| F2.1–F2.4 | OCR, dictation, capture, cheatsheet — pre-existing | — |
| F2.5 | Nautilus integration (open-any-terminal + LocalSend action) | [#106](https://github.com/Jylhis/marchyo/pull/106) |
| F2.6 | Plymouth re-skin from Jylhis tokens — pre-existing (v4.0.0) | — |
| F3.1 | CLI system subcommands (`update upgrade rollback gc diff debug`) + options-eval host detection | [#121](https://github.com/Jylhis/marchyo/pull/121) |
| — | OMARCHY_PARITY.md Part B (menus, OSD, DND, clipboard, binds, utilities, screensaver, runtime light/dark) | #107 #110 #111 #113 #115 #118 #119 #120 |

### Conventions every item follows
- New options go in a file under `modules/nixos/options/<namespace>.nix`
  (auto-discovered). New NixOS/Home modules drop into `modules/nixos/` or
  `modules/home/` (auto-discovered); darwin needs a manual import edit.
- **⚠ Darwin eval gate:** `modules/darwin/default.nix` imports
  `../nixos/options`, so *every* new option file is evaluated on darwin too.
  Keep new option files **declaration-only with platform-neutral defaults**.
  Put all package refs in the NixOS impl modules.
- Gate everything behind `marchyo.*` flags using `lib.mkIf` / `lib.mkDefault`.
- Add an eval test in `tests/eval/<feature>.nix` for each new module.
- Run `just fmt` + `just check` before every commit; conventional commits.

---

## Remaining work

### F1.11 — Local AI integration (deferred)
- **Status:** `marchyo.ai.local.enable` is **declared but unimplemented** —
  enabling it currently fails an assertion (use OpenRouter instead).
- **Goal:** `marchyo.ai.local.enable` → `services.ollama` (with
  `acceleration = "cuda"|"rocm"` driven by `marchyo.graphics.vendors`),
  optional model pre-pull; expose endpoint to shell/editor/tracking.
- **Files:** new `modules/nixos/ollama.nix`; option in `ai.nix`.
- **Decision D1 (open):** tracking already runs **llama-cpp**
  (`tracking/analysis.nix` → `marchyo-llama-server`). Adding ollama = two
  local-inference stacks. *Recommended:* keep llama.cpp for tracking + ollama
  for user AI and document both (least churn); revisit convergence later.
- **Effort:** M. **Notes:** acceleration wiring should read graphics vendors so
  CUDA/ROCm is automatic.

### F3.0 — Unified runtime-first change model (design foundation)
Every *mutating* CLI command follows one three-mode contract (generalizing the
existing `theme set --rebuild`):
- **default = runtime:** apply live (`hyprctl`/`systemctl --user`/`makoctl`/
  symlink swap) + persist an ephemeral override under
  `~/.local/state/marchyo/runtime.json` so it survives `hyprctl reload`.
- **`--apply` (persist):** additionally write the key into the declarative
  drop-in `/etc/marchyo/cli-state.json` (existing `marchyoCliState` → `marchyo.*`
  at `mkDefault`) and run `nixos-rebuild`. Survives reboot; flake config wins.
- **`--revert` (reverse):** undo — drop the runtime override and/or delete the
  persisted key + rebuild. Symmetric with `--apply`.
- **New core helpers:** `core/src/runtime-state.ts`, `core/src/apply.ts`,
  `core/src/hypr.ts`; reuse existing `state.ts`/`flake.ts`/`nix.ts`/`output.ts`
  and the new `system.ts` (`sudoWrap`, `runArgv` from #121).
- **Building blocks that now exist:** `marchyo-theme-toggle` (#118, symlink-swap
  + reload pattern), the window-toggle scripts, `marchyo-dnd-toggle` (#110).

### F3.2 — Full CLI command surface (runtime toggles + helpers)
- **Runtime toggles** (F3.0 contract, `toggle <name> [on|off] [--apply] [--revert]`):
  - Display/visual: `gaps`, `transparency`, `nightlight`, `waybar`
  - Input: `touchpad`, `touchscreen`
  - Session/idle: `idle`, `screensaver`, `notifications` (wraps `marchyo-dnd-toggle`), `suspend`
  - `hybrid-gpu` (hardware-specific; runtime where safe, else `--apply`-only)
- **Capture:** `capture screenshot|record [--audio none|desktop|mic]|ocr|color`
  (wrap the existing screenshot/OCR/record/hyprpicker scripts).
- **Menu + launchers:** `menu` (wrap `marchyo-menu`, #113), `keybindings`
  (wrap `marchyo-keybindings`), `launch <app>` / `focus-or-launch <app>`.
- **Power/session:** `lock`, `logout`, `reboot`, `shutdown`, `suspend`,
  `powerprofile get|list|set` (wrap `marchyo-power-menu` actions, #113).
- **Media + font:** `transcode` (wrap `marchyo-transcode`, #115), `font
  list|current|set`.
- **Declarative ergonomics (`--apply`-only):** `install <feature>` / `remove
  <feature>` / `toggle <feature>` for coarse flags edit `cli-state.json` then
  rebuild; `webapp add <url>` / `webapp rm`; `security enroll fido2|fingerprint`
  (wraps `fprintd-enroll`/`pamu2fcfg`, #117).
- **Files:** command modules under
  `packages/marchyo-cli/packages/user-cli/src/commands/`.
- **Effort:** L. **Notes:** most helper scripts now exist as `marchyo-*`
  binaries — the CLI surface is a thin dispatch layer over them.

### F3.3 — Multi-theme runtime switching
- **Status:** the dark↔light runtime toggle MVP shipped (#118:
  `modules/home/theme-runtime.nix` + `marchyo-theme-toggle`, symlink-swap +
  live reload, ephemeral-overlay contract). Remaining: generalize beyond the
  two Jylhis variants.
- **Goal:** switch among multiple themes at runtime (omarchy ships 21).
- **Mechanism:** extend the per-variant store-dir + pointer layout from #118 to
  N variants built from base16 schemes (`marchyo.theme.scheme`); add
  `marchyo theme set <name>` / `marchyo theme cycle` CLI wiring; background
  switcher.
- **Files:** extend `modules/home/theme-runtime.nix`; switcher in
  `packages/marchyo-cli/`.
- **Effort:** M–L (reduced — the swap/reload mechanism is proven).
- **Follow-ups from #118:** hyprlock live color swap (via `source =` include);
  central-menu Style entry can call `marchyo-theme-toggle` directly.

---

## Verification (per feature + overall)
- **Per module:** add `tests/eval/<feature>.nix` (use `testNixOS`/`withTestUser`
  from `tests/lib.nix`); `nix flake check` must pass.
- **Desktop/runtime features:** eval-test the module, then **manually verify in
  the VM** via `just run` — exercise each keybind/menu and confirm.
- **CLI:** `bun test` in `packages/marchyo-cli`; integration-test
  `upgrade`/`rollback` against a throwaway generation; never auto-`nixos-rebuild`
  in CI.
- **Darwin:** when adding/editing files under `modules/nixos/options/`, confirm
  `aarch64-darwin` still evaluates.
- **Gate:** `just fmt` + `just check` green before each commit;
  conventional-commit messages; update `docs/configuration/` option docs in
  sync with new `modules/nixos/options/*`.

## Out of scope (Nix subsumes or low value)
- omarchy's `update`/`migrate` engine, `omarchy-refresh-*`, AUR tooling →
  `nixos-rebuild` + `flake.lock` + generations already cover this.
- Dev-environment installers (mise Rails/Go/…) → per-project `nix develop`/devenv.
- Bespoke per-model kernel patches → expose kernel package choice, not patches.
- Windows VM → large, niche; defer unless requested.
