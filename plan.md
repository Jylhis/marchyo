# Marchyo Feature Roadmap — Omarchy Parity & Beyond

> Derived from the omarchy↔marchyo gap analysis. Targets 24 requested features,
> grouped into dependency-ordered phases. Each item lists
> **goal · mechanism · files · reuse · effort · notes**.
>
> **Validated 2026-05-29** against the live tree (3 Explore agents + targeted
> reads). Items carrying a **✓ validated** / **⚠ corrected** marker were checked;
> see each note for what changed.

## Context

Marchyo is a declarative NixOS/Home-Manager flake reimagining omarchy (now at
v3.8.2; marchyo's baseline is the v3.0 fork). This plan closes the capability
gap while staying Nix-idiomatic. The central tension to manage throughout:
omarchy mutates a running system imperatively; marchyo rebuilds declaratively.
Three features deliberately straddle that line — the **unified CLI**, **runtime
toggles**, and **runtime theme switching** — and are designed below to add
runtime ergonomics *without* abandoning the declarative source of truth.

### Conventions every item follows
- New options go in a file under `modules/nixos/options/<namespace>.nix`
  (auto-discovered). New NixOS/Home modules drop into `modules/nixos/` or
  `modules/home/` (auto-discovered); darwin needs a manual import edit.
- **⚠ Darwin eval gate:** `modules/darwin/default.nix` imports
  `../nixos/options`, so *every* new option file is evaluated on darwin too.
  Keep new option files **declaration-only with platform-neutral defaults** —
  any `default` referencing a Linux-only package (tailscale, ollama, localsend,
  plymouth…) breaks darwin eval. Put all package refs in the NixOS impl modules.
  Add `aarch64-darwin` eval coverage when touching option files.
- Gate everything behind `marchyo.*` flags using `lib.mkIf` / `lib.mkDefault`.
- Add an eval test in `tests/eval/<feature>.nix` for each new module.
- New scripts: prefer **Go** single-binary, else Bash for <5-line wrappers
  (per repo script-language preference).
- Run `just fmt` + `just check` before every commit; conventional commits.

---

## Phase 0 — Foundations (unblocks the rest)

### F0.1 — AGENTS ai guidance ⚠ corrected
- **Goal:** Make repo-root `AGENTS.md` the tool-agnostic agent-guidance SOT,
  covering how to add/remove modules, the flag model, and the
  declarative-vs-imperative rules so agents don't reach for `pkg-add`.
- **⚠ Reality:** `AGENTS.md` *already exists* but is a 3-line stub pointing
  *to* `CLAUDE.md` — the inverse of the intended pattern. `CLAUDE.md` does not
  `@`-import it.
- **Files:** **invert the relationship** — move the tool-agnostic content out of
  `CLAUDE.md` into `AGENTS.md`, then have `CLAUDE.md` `@AGENTS.md`-import it
  (mirrors the user's global pattern). Distill, don't duplicate.
- **Effort:** S. **Notes:** docs-only, no eval impact.

### F0.2 — Per-machine hardware fixes via nixos-hardware
- **Goal:** Make `inputs.nixos-hardware` (already pinned, currently **unused**)
  consumable. Hardware fixes come from nixos-hardware by default.
- **Mechanism:** re-export curated profiles as
  `nixosModules.hardware.<vendor-model>` in `outputs.nix` (thin wrappers around
  `inputs.nixos-hardware.nixosModules.*`), plus document the
  `marchyo.inputs.nixos-hardware` passthrough for downstream `imports`.
  Avoid a `marchyo.hardware.profile` enum — NixOS `imports` can't be chosen by
  config value, so re-export + downstream-import is the correct pattern.
- **Files:** `outputs.nix` (add `nixosModules.hardware.*`); `docs/` note;
  `templates/workstation/configuration.nix` example import (commented).
- **Effort:** S–M. **Notes:** marchyo's own `graphics.nix`/PRIME stays the
  generic fallback; nixos-hardware handles model-specific quirks.

### F0.3 — Option namespaces scaffold ✓ validated
- **Goal:** Declare the new `marchyo.*` namespaces the phases below need.
- **Files (new under `modules/nixos/options/`):** `security.nix`
  (firewall, fido2, fingerprint), `services.nix` (tailscale, localsend,
  sunshine…), `power.nix` (hibernation, kernel), `storage.nix` (btrfs/snapshots),
  `ai.nix` (tooling, local) **✓ implemented**, `webapps.nix`,
  `brand.nix` (theme/plymouth/assets).
  None of these exist yet — all genuinely new. A new `options/security.nix` is a
  *declarations* file and won't collide with the existing config module
  `modules/nixos/security.nix` (polkit-only).
- **⚠ Note:** `options/hardware.nix` already exists (unmentioned originally) —
  kernel (F1.3) and vulkan (F1.4) options may belong there or in the existing
  `performance.nix`/`graphics.nix` rather than fresh files. Respect the **Darwin
  eval gate** (see Conventions): declaration-only, platform-neutral defaults.
- **Effort:** S (declarations only; impl lands per-feature).

---

## Phase 1 — Declarative system modules (pure Nix, low risk)

### F1.1 — Firewall setup
- **Goal:** `marchyo.security.firewall.enable` (default on with desktop) wrapping
  `networking.firewall` with sane defaults + per-service port helpers consumed
  by localsend/sunshine/tailscale.
- **Files:** new `modules/nixos/security-firewall.nix`; options in `security.nix`.
- **Reuse:** existing `modules/nixos/security.nix` (polkit-only today).
- **Effort:** S.

### F1.2 — Tailscale feature toggle
- **Goal:** `marchyo.services.tailscale.enable` → `services.tailscale.enable`
  + `networking.firewall.trustedInterfaces = [ "tailscale0" ]` + checkReversePath fix.
- **Files:** new `modules/nixos/tailscale.nix`; option in `services.nix`.
- **Effort:** S.

### F1.3 — Modern kernel + advanced features ⚠ corrected
- **Goal:** `marchyo.performance.kernel = "latest"|"zen"|"xanmod"|"lts"|"default"`
  → `boot.kernelPackages`; optional zram, sysctl/efficiency tuning.
- **⚠ Reality:** `hardware.nix` has `thermald` (line 39) but **no Intel LPMD**
  (original claim was wrong) and **no zram** anywhere — both are new work. No
  kernel-selection option or `boot.kernelPackages` exists yet.
- **Files:** extend `modules/nixos/performance.nix` + `options/performance.nix`.
- **Reuse:** existing `performance.nix` (`disableMitigations` flag), `hardware.nix`.
- **Effort:** S–M. **Notes:** custom kernel *patches* (omarchy's Panther-Lake
  6.19) are out of scope; expose package choice, not bespoke kernels.

### F1.4 — Hardware acceleration (round out)
- **Goal:** Ensure complete VAAPI/Vulkan/NVENC/ROCm coverage and the
  `nixVersions`/32-bit bits across vendors.
- **Files:** extend `modules/nixos/graphics.nix` (already strong: intel-media-driver,
  vpl-gpu-rt, compute-runtime, amdgpu, nvidia-vaapi). Add `vulkan-loader`/
  `vulkan-tools`, AMD `rocmPackages` completeness, NVENC note.
- **Effort:** S. **Notes:** mostly present; this is a completeness pass.

### F1.5 — Hibernation options ⚠ corrected
- **Goal:** `marchyo.power.hibernation.enable` → swap device/zram-backed
  resume, `boot.resumeDevice`, and wire hypridle's currently-commented suspend
  into suspend-then-hibernate.
- **⚠ Reality:** `disko/luks-btrfs.nix` already provisions an 8 GB encrypted
  swap partition (lines 108–114) — the "provision swap" sub-task is done. But
  **8 GB is likely < RAM → insufficient for true hibernate-to-disk**; resize to
  ≥ RAM (or zram+disk) on hibernation hosts. `hypridle.nix` suspend confirmed
  commented (lines 28–31).
- **Files:** new `modules/nixos/hibernation.nix`; option in `power.nix`;
  edit `modules/home/hypridle.nix`; resize swap in `disko/luks-btrfs.nix`.
- **Effort:** S–M (reduced — swap exists). **Notes:** requires swap ≥ RAM (or
  zram+disk); document on encrypted setups.

### F1.6 — FIDO2 + fingerprint
- **Goal:** `marchyo.security.fingerprint.enable` → `services.fprintd` + PAM;
  `marchyo.security.fido2.enable` → `security.pam.u2f` + enrollment helper script.
- **Files:** new `modules/nixos/security-auth.nix`; options in `security.nix`;
  `hyprlock.nix` already *consumes* fingerprint (close the loop).
- **Effort:** M. **Notes:** enrollment is inherently imperative (`fprintd-enroll`,
  `pamu2fcfg`); ship a `marchyo`-CLI subcommand wrapper, not a Nix activation.

### F1.7 — Full btrfs integration + snapshots ⚠ corrected
- **Goal:** Proper subvolume layout with compression/noatime, plus automated
  snapshots & retention.
- **⚠ Reality:** `disko/luks-btrfs.nix` **already** has the full layout —
  `@root @home @nix @persist @log @snapshots`, `compress=zstd`, `noatime`, and
  swap. Only `disko/btrfs.nix` (flat, unencrypted) needs the subvolume rewrite.
  **Decision D2:** align `btrfs.nix` to the existing scheme (`@root` not `@`,
  plus `@persist`) so both variants match. snapper/btrbk genuinely absent.
- **Mechanism:** `services.snapper` (timeline + number cleanup) or `services.btrbk`;
  rollback helper. Boot-menu snapshot selection isn't native to systemd-boot —
  rely on NixOS generations for the OS + snapper for `/home` data rollback.
- **Files:** new `modules/nixos/btrfs.nix` + options in `storage.nix`; rewrite
  **`disko/btrfs.nix` only** to match `luks-btrfs.nix`'s subvolume layout.
- **Effort:** S–M (reduced — luks variant already done). **Notes:** omarchy
  dropped /home btrfs snapshots over churn; default to conservative retention
  (e.g. snapper timeline, keep ~5).

### F1.8 — LocalSend
- **Goal:** `marchyo.services.localsend.enable` → package + firewall ports
  (TCP/UDP 53317) + autostart + Nautilus send action.
- **Files:** new `modules/home/localsend.nix` (or nixos), firewall hook (F1.1),
  Nautilus action (ties into F2.5).
- **Effort:** S–M.

### F1.9 — Web-app installation (declarative-first)
- **Goal:** `marchyo.webapps.<name> = { url; icon?; categories?; }` generating
  `.desktop` entries that launch `$browser --app=<url>` with proper WM_CLASS,
  so they tile/theme correctly. Optional CLI `marchyo webapp add` (Phase 3).
- **Mechanism:** `xdg.desktopEntries` in a Home module; fetch/derive icons.
- **Files:** new `modules/home/webapps.nix`; option in `webapps.nix`;
  window rules already exist in `modules/home/hyprland.nix` (reuse the
  chromium `--app` tagging).
- **Reuse:** existing `$webapp` var + chromium window rules in `hyprland.nix`.
- **Effort:** M. **Notes:** the declarative path is the Nix-idiomatic win over
  omarchy's imperative `omarchy-webapp-install`.

### F1.10 — AI tooling ✓ implemented (OpenRouter BYOK)
- **Status:** Done. `marchyo.ai.*` namespace (`modules/nixos/options/ai.nix`),
  guardrails (`modules/nixos/ai.nix`), client install + key export + per-tool
  routing (`modules/home/ai-tooling.nix`: aichat + pi + claude-code), OpenViking
  context (`modules/home/ai-context.nix`), Agent Skills
  (`modules/home/ai-skills.nix`), MCP tools (`modules/home/ai-mcp.nix`), and a
  `Super+A` aichat keybind. Packages: `packages/openviking`, `packages/pi`.
  Secrets via **sops-nix** (flake input; wired in `outputs.nix`). claude-code
  stays on the Anthropic API (not wired to OpenRouter). aider/opencode and the
  Emacs/gptel integration were dropped. Tests in `tests/eval/ai.nix`; docs in
  `docs/configuration/ai.mdx`.
- **Goal:** `marchyo.ai.tooling.enable` installs the AI client CLIs (aichat +
  pi wired to OpenRouter, plus Anthropic-native claude-code from llm-agents.nix)
  for the user. (opencode/aider were dropped — see note above.)
- **Files:** new `modules/home/ai-tooling.nix`; option in `ai.nix`.
- **⚠ Reuse:** `modules/home/claude-code.nix` only installs a `SKILL.md` doc
  (gated on `development.enable`) — it installs **no CLI packages**. So this is
  genuinely new work; at most *colocate* with claude-code.nix, don't "reuse" it.
- **Effort:** S–M. **Notes:** pin to nixpkgs packages; skip npx lazy-stubs
  (that's omarchy working around Arch — Nix pins versions instead).

### F1.11 — Local AI integration ⚠ corrected (deferred)
- **Status:** `marchyo.ai.local.enable` is **declared but unimplemented** —
  enabling it currently fails an assertion (use OpenRouter instead). The ollama
  service + D1 convergence are still open; OpenRouter BYOK shipped first (F1.10).
- **Goal:** `marchyo.ai.local.enable` → `services.ollama` (with
  `acceleration = "cuda"|"rocm"` driven by `marchyo.graphics.vendors`),
  optional model pre-pull; expose endpoint to shell/editor/tracking.
- **Files:** new `modules/nixos/ollama.nix`; option in `ai.nix`.
- **⚠ Reality / Decision D1:** tracking already runs **llama-cpp**
  (`tracking/analysis.nix` → `marchyo-llama-server`), **not ollama** (no
  `services.ollama` exists). Adding ollama = two local-inference stacks. Pick:
  (a) converge tracking onto ollama, (b) keep llama.cpp for tracking + ollama
  for user AI and document both *(recommended short-term — least churn)*, or
  (c) expose llama.cpp to the user too and skip ollama.
- **Effort:** M. **Notes:** acceleration wiring should read graphics vendors so
  CUDA/ROCm is automatic.

---

## Phase 2 — Desktop capability gaps (tools + keybinds + waybar)

### F2.1 — OCR (text extraction)
- **Goal:** Screen-region OCR → clipboard, on a keybind (mirror omarchy's
  `Super+Ctrl+PrtScr`).
- **Mechanism:** `grim -g "$(slurp)" - | tesseract - - | wl-copy` wrapper script.
- **Files:** new `modules/home/ocr.nix` (script via `pkgs.writeShellApplication`
  + `tesseract`, `slurp`, `grim`, `wl-clipboard`); keybind in `hyprland.nix`.
- **Reuse:** screenshot pattern in `modules/home/screenshot.nix`.
- **Effort:** S.

### F2.2 — Dictation
- **Goal:** Push-to-talk voice typing into the focused field (omarchy uses
  Voxtype on F9).
- **Mechanism:** Voxtype isn't in nixpkgs → use `nerd-dictation`+vosk or
  `whisper.cpp` + a `wtype` output script; GPU-accel optional.
- **Files:** new `modules/home/dictation.nix`; keybind in `hyprland.nix`;
  option in `ai.nix` (it's speech-AI adjacent).
- **Effort:** M–L. **Notes:** **packaging risk** — confirm a working
  nixpkgs path; may need a small package in `packages/`. Flag as the least
  certain item.

### F2.3 — Capture menu round-out (screen-record + color picker) ✓ validated
- **Goal:** Bind screen recording with audio modes + add a color picker.
- **Mechanism:** `wf-recorder` (already installed) wrapper with
  none/desktop/mic audio variants + `-14 LUFS` normalize option; `hyprpicker`
  for color → clipboard.
- **Files:** extend `modules/home/screenshot.nix` (or new `capture.nix`);
  add `hyprpicker` package + keybind.
- **⚠ Reuse note:** `wf-recorder` confirmed in `hyprland.nix:446` (unbound);
  `hyprpicker` absent (new). `screenshot.nix` builds its actions as **inline
  `bindd` commands (grimblast+satty), not `writeShellApplication`** — follow that
  inline pattern, or introduce `writeShellApplication` here fresh.
- **Effort:** S–M.

### F2.4 — Keybinding cheatsheet ⚠ corrected (easier than stated)
- **Goal:** On-demand overlay listing keybinds (omarchy's "Learn" menu).
- **Mechanism:** **Generate** the cheatsheet at build time from the *same* bind
  definitions in `modules/home/hyprland.nix` (single source of truth → no drift),
  render via a launcher (vicinae/fuzzel) or a styled pager.
- **⚠ Reality:** binds are **already a structured Nix list** —
  `bindd = [ "SUPER, return, Terminal, exec, $terminal" … ]` (31 described
  tuples, `hyprland.nix:284`). The proposed "refactor into a shared list" is
  largely unnecessary; generate the cheatsheet directly from `bindd`.
- **Files:** new `modules/home/cheatsheet.nix` consuming the existing `bindd`.
- **Effort:** S (reduced from M). **Notes:** build-time generation is the
  Nix-idiomatic edge over omarchy's hand-maintained list. **Quick win.**

### F2.5 — File explorer (full integration)
- **Goal:** Nautilus with extensions: open-in-ghostty, LocalSend send,
  transcode action, OCR action, theming.
- **Files:** new `modules/home/nautilus.nix` (nautilus-python +
  `nautilus-open-any-terminal` configured for ghostty + custom actions).
- **Reuse:** F1.8 (localsend), F2.1 (OCR); `defaults.nix` already picks nautilus.
- **Effort:** M.

### F2.6 — Updated Plymouth theme + marchyo brand assets ⚠ corrected
- **Goal:** Refresh `plymouth-marchyo-theme` (pinned at the stale v3.0 fork) and
  establish a coherent **marchyo theme/brand**: logo, per-variant wallpapers,
  about/screensaver ASCII, greeter matching.
- **⚠ Reality:** Plymouth **is** already wired — `modules/nixos/plymouth.nix`
  enables `boot.plymouth` with `pkgs.plymouth-marchyo-theme` in initrd-systemd;
  `theme.nix:36` disables Stylix's plymouth target (marchyo themes it directly).
  The package is pinned v3.0.0 with hardcoded RGB, no Jylhis palette → re-skin is
  valid. The **greeter (tuigreet) is separate and already themed**
  (`boot.nix:21-36`) — narrow this item to the splash, not the greeter.
- **Files:** update `packages/plymouth-marchyo-theme/package.nix` (bump src +
  version, re-skin to Jylhis palette); new brand assets dir; options in `brand.nix`.
- **Reuse:** `jylhis-palette.nix` for colors; existing `plymouth.nix` wiring.
- **Effort:** M. **Notes:** "marchyo theme" = brand identity layered on the
  Jylhis design system, not a 4th base16 scheme.

---

## Phase 3 — CLI & runtime UX layer (architectural)

> **Scope decided 2026-07-17** (omarchy-CLI gap analysis + user scope choices):
> match omarchy's *ergonomics* across all runtime-toggle groups and all UX
> helper groups, ship full runtime theme switching, and give install/toggle a
> unified runtime-first model. **Language correction:** the real
> `packages/marchyo-cli/` is a **Bun + TypeScript + Ink** monorepo (`core/`,
> `user-cli/`, `dev-cli/`), NOT the Go binary earlier drafts assumed. It is
> already fully wired (overlay, `outputs.nix` `mkPackages`, real `outputHash`,
> `marchyo.cli.enable` default `true`, `cli-state.json`/`marchyoCliState`).

### F3.0 — Unified runtime-first change model (design foundation)
Every *mutating* command follows one three-mode contract (generalizing the
existing `theme set --rebuild`):
- **default = runtime:** apply live (`hyprctl`/`systemctl --user`/`hyprsunset`/
  `makoctl`/symlink swap) + persist an ephemeral override under
  `~/.local/state/marchyo/runtime.json` so it survives `hyprctl reload`. Instant,
  no rebuild.
- **`--apply` (persist):** additionally write the key into the declarative
  drop-in `/etc/marchyo/cli-state.json` (existing `marchyoCliState` → `marchyo.*`
  at `mkDefault`) and run `nixos-rebuild`. Survives reboot; flake config wins.
- **`--revert` (reverse):** undo — drop the runtime override (reload declarative
  value) and/or delete the persisted key + rebuild. Symmetric with `--apply`.
- **New core helpers:** `core/src/runtime-state.ts`, `core/src/apply.ts`,
  `core/src/hypr.ts`; reuse existing `state.ts`/`flake.ts`/`nix.ts`/`output.ts`.

### F3.1 — Unified `marchyo` CLI + system management
- **Goal:** One entrypoint (`marchyo`) for system mgmt + UX, replacing the
  scattered `just` recipes for end users.
- **Implemented today:** `status`, `theme get`, `theme set <dark|light>
  [--rebuild]`, `rebuild [-n]`; global flags `-F/--format`, `--json`, `--color`,
  `--no-color`, `--plain`, `--no-animation`, `--no-input`, `-q`, `-v`.
- **System subcommands (declarative wrappers):** `rebuild` ✓, `upgrade` (update
  inputs + rebuild), `update`, `rollback`, `gc`, `diff` (reuse
  `modules/nixos/update-diff.nix`), `status` ✓, `debug` (diagnostics bundle ←
  omarchy debug/upload-log).
- **UX subcommands:** `theme` (F3.3), `toggle` (F3.2), `capture`, `menu`/
  `keybindings`/`launch`/`focus-or-launch`, `power`/`session`, `font`, `media`
  (see F3.2 for the full surface).
- **Mechanism:** Bun/TS/Ink monorepo (already wired). Fix the hardcoded
  `nixosConfigurations.x86_64` in `options-eval.ts:24`.
- **Effort:** L. **Notes:** for declarative subcommands (`upgrade`,`rollback`)
  this is a thin, safe wrapper.

### F3.2 — Full command surface: runtime toggles, helpers, declarative ergonomics
Scope = match omarchy across all groups the user selected.

- **Runtime toggles** (F3.0 contract, `toggle <name> [on|off] [--apply] [--revert]`):
  - Display/visual: `gaps`, `transparency`, `nightlight`, `waybar`
  - Input: `touchpad`, `touchscreen`
  - Session/idle: `idle`, `screensaver`, `notifications` (mako silence), `suspend`
  - `hybrid-gpu` (hardware-specific; runtime where safe, else `--apply`-only)
- **Capture** (CLI wraps plan F2.1 OCR + F2.3 record/picker): `capture
  screenshot|record [--audio none|desktop|mic]|ocr|color`.
- **Menu + launchers:** `menu` (root launcher tree via fuzzel/vicinae),
  `keybindings` (cheatsheet generated from `hyprland.nix` `bindd`, F2.4),
  `launch <app>` / `focus-or-launch <app>` (single-instance ← omarchy launch-or-focus).
- **Power/session:** `lock`, `logout`, `reboot`, `shutdown`, `suspend`,
  `powerprofile get|list|set` (power-profiles-daemon).
- **Media + font:** `transcode <file> [--ascii]` (ffmpeg), `font list|current|set`
  (runtime font switch through themed surfaces, `--apply` persists).
- **Declarative ergonomics (`--apply`-only — no runtime path):** `install
  <feature>` / `remove <feature>` and `toggle <feature>` for coarse flags
  (gaming, tailscale, localsend…) edit `cli-state.json` then rebuild; `webapp add
  <url>` / `webapp rm` (F1.9); `security enroll fido2|fingerprint` (F1.6).
- **Out of scope (Nix subsumes):** omarchy `update`-engine internals, `reinstall`,
  `migrate`, `channel`/`branch`, `refresh-*` config regen, `hw-*` device fixes
  (→ nixos-hardware, F0.2), `drive`, `tz-select`, `version-pkgs`.
- **Files:** command modules under `packages/marchyo-cli/packages/user-cli/src/
  commands/`; supporting modules reuse F2.1 (`ocr.nix`), F2.3 (capture), F2.4
  (`cheatsheet.nix`), F1.9 (`webapps.nix`); feature flags surfaced via
  `cli-state.json`.
- **Effort:** L. **Notes:** `install`/`toggle <feature>` reconfigure + rebuild
  (not instant); runtime toggles are instant.

### F3.3 — Runtime theme switching
- **Goal:** Switch among multiple themes at runtime without a full rebuild
  (omarchy ships 21; marchyo has Roast/Paper today).
- **Mechanism (feasible because Stylix is already disabled for the surfaces
  marchyo hand-themes — waybar/hyprland/mako/ghostty/hyprlock/bat/fzf/console/
  starship per `modules/generic/theme.nix`):**
  1. Build *all* theme variants as derivations (each emits the marchyo-managed
     config set: waybar CSS, hyprland colors, ghostty/mako/bat/hyprlock, wallpaper)
     from `jylhis-palette.nix` and/or base16 schemes.
  2. `marchyo theme set <name>` repoints `~/.config` symlinks to the chosen
     variant's store path and reloads waybar/hyprland/mako/hyprsunset.
  3. Stylix-only targets (qt/gtk/gnome/fontconfig) stay build-time; document
     that those follow the rebuilt default, not the runtime switch.
- **Files:** new `modules/home/theme-variants.nix` (builds the variant set);
  switcher in `packages/marchyo-cli/`; refactor `jylhis-theme.nix` /
  `generic/theme.nix` to parameterize over a variant set; background switcher.
- **Effort:** L (largest/riskiest).
- **Notes / decision:** This is the deepest divergence from pure declarative.
  Recommended scope: ship Roast/Paper + a few base16 variants first, prove the
  symlink-swap + reload, then expand. Keep the build-time default as the
  reproducible source of truth; runtime switch is an ephemeral overlay.

---

## Open decisions (resolve before the affected feature)

- **D1 (F1.11) — ollama vs llama.cpp.** Tracking already runs llama-cpp. Adding
  `services.ollama` = two inference stacks. *Recommended:* keep llama.cpp for
  tracking + ollama for user AI and document both (least churn); revisit
  convergence later.
- **D2 (F1.7) — subvolume naming.** Align `disko/btrfs.nix` to the existing
  `luks-btrfs.nix` scheme (`@root @home @nix @persist @log @snapshots`).

## Suggested sequencing & rationale

1. **Phase 0** first — AGENTS.md (*invert existing stub*), nixos-hardware
   re-export, and option scaffolds unblock everything and are low-risk. Mind the
   **Darwin eval gate** when adding option files.
2. **Phase 1** next — each is an independent, testable Nix module with clear
   upstream NixOS support; highest value-to-effort. Order within: firewall →
   tailscale → kernel/accel (*drop LPMD claim*) → fido2/fingerprint →
   hibernation (*swap exists, resize for hibernate*) → btrfs (*`btrfs.nix`
   only*) → localsend → webapps → ai-tooling (*new, not reuse*) → ollama
   (*resolve D1 first*).
3. **Phase 2** — desktop polish; depends on some Phase 1 (localsend/OCR feed
   the file-explorer + capture work). Cheatsheet (F2.4) drops to **S**; F2.6
   narrows to the Plymouth splash (greeter already themed).
4. **Phase 3** last — the CLI (*flesh out existing stub*) consumes everything
   above; runtime theming is the final, biggest piece. Land the CLI's safe
   declarative subcommands before the install/toggle/theme-switch behaviors.

**Quick wins to front-load** (all smaller than originally stated): F0.1 (AGENTS
invert), F2.4 (cheatsheet from `bindd`), F1.7 (`btrfs.nix` only).

## Verification (per feature + overall)
- **Per module:** add `tests/eval/<feature>.nix` (use `testNixOS`/`withTestUser`
  from `tests/lib.nix`); `nix flake check` must pass. Many features (firewall,
  tailscale, kernel, hibernation, fido2, btrfs, ollama, webapps) are
  eval-verifiable without a build.
- **Desktop/runtime features** (OCR, dictation, capture, cheatsheet, file
  explorer, theme switch, CLI toggles): eval-test the module, then **manually
  verify in the VM** via `just run` (or `just build-nixos`) — these can't be
  fully validated by eval alone; exercise each keybind/menu and confirm.
- **CLI:** unit-test the Go binary; integration-test `upgrade`/`rollback`
  against a throwaway generation; never auto-`nixos-rebuild` in CI.
- **Darwin:** when adding/editing files under `modules/nixos/options/`, confirm
  `aarch64-darwin` still evaluates (the darwin module imports `../nixos/options`).
- **Gate:** `just fmt` + `just check` (nixfmt, deadnix, statix, eval) green
  before each commit; conventional-commit messages; update `docs/configuration/`
  option docs in sync with new `modules/nixos/options/*`.

## Out of scope (Nix subsumes or low value)
- omarchy's `update`/`migrate` engine, `omarchy-refresh-*`, AUR tooling →
  `nixos-rebuild` + `flake.lock` + generations already cover this.
- Dev-environment installers (mise Rails/Go/…) → per-project `nix develop`/devenv.
- Bespoke per-model kernel patches → expose kernel package choice, not patches.
- Windows VM → large, niche; defer unless requested.
