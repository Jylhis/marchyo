# CLAUDE.md

@AGENTS.md

[AGENTS.md](AGENTS.md) holds the distilled tool-agnostic agent guidance (imported above); this file is the full detailed reference for Claude Code (claude.ai/code).

## Project Overview

Marchyo is a modular NixOS configuration flake providing curated system, Home Manager, nix-darwin, and nix-on-droid configurations with sensible defaults. It is distributed as a batteries-included Nix flake meant to be used as the sole input in downstream configurations: consumers build with the `marchyo.lib.mkNixosSystem` / `mkDarwinSystem` builders, which select the system-correct nixpkgs + home-manager + stylix automatically (x86_64-darwin → stable 26.05, everything else → unstable).

**Key features:**
- Modular architecture: configurations broken into small, manageable modules
- Feature flags: `marchyo.desktop.enable`, `marchyo.development.enable`, etc. enable entire stacks
- Home Manager integration for user-specific configurations and dotfiles
- nix-darwin support for macOS system configuration
- nix-on-droid support for an Android terminal environment (CLI-only), a first-class build target via `marchyo.lib.mkNixOnDroidConfiguration`
- Hardware support via `nixos-hardware` with NVIDIA/PRIME graphics options
- All custom options live under the `marchyo.*` namespace
- Multi-nixpkgs: the primary `nixpkgs` input is **unstable**; a separate `nixpkgs-stable` (nixos-26.05) backs `darwinConfigurations.x86_64` only. `home-manager`/`nix-darwin`/`stylix` track `master` to pair with unstable. A matching trio of release-26.05 inputs — `home-manager-stable`, `nix-darwin-stable`, `stylix-stable`, all following `nixpkgs-stable` — pairs with the stable set so `darwinConfigurations.x86_64` runs releases matching its nixpkgs (nix-darwin hard-fails the build on a release mismatch; home-manager and stylix warn). nix-on-droid is pinned independently (its own 2024-era nixpkgs + `home-manager-droid`).
- Nixpkgs passthrough: downstream consumers only need `inputs.marchyo`; `marchyo.lib.*` builders and `legacyPackages.<system>` give a system-correct nixpkgs (x86_64-darwin → stable 26.05)

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

There is no way to run a single test in isolation; `nix flake check` runs them all (they are fast evaluation-only checks).

## Code Style

- Format with `just fmt` (or `nix fmt`) before committing — this is mandatory, CI enforces it
- Follow conventional commit message format (e.g. `feat:`, `fix:`, `chore:`)
- Use `lib.mkIf cfg.someFlag` for conditional configuration
- Use `lib.mkDefault` for options that consumers should be able to override
- All custom options must be defined under `modules/nixos/options/` in the `marchyo.*` namespace (one file per logical namespace; auto-discovered)

## Architecture

### Hybrid Non-Flake + Flake Architecture

All real Nix logic lives in plain Nix files. `flake.nix` is a thin re-export wrapper that imports `outputs.nix` and forwards outputs. `default.nix` is a flake-compat shim for non-flake consumers (devenv, `nix-build`). Development uses `devenv.sh` (no experimental features required). `flake.lock` is the source of truth for input revisions; the devenv dev shell tracks the primary (unstable) `nixpkgs`, synchronized to `devenv.lock` via `just update`.

### Module Organization

```
flake.nix           # Flake entry point — imports outputs.nix, wraps per-system outputs
flake.lock          # Single source of truth for all pinned inputs (nixpkgs, home-manager, etc.)
outputs.nix         # All output logic — takes { inputs }, returns modules, packages, checks, etc.
default.nix         # Flake-compat shim — exposes flake outputs to non-flake consumers
overlay.nix         # Nixpkgs overlay (vicinae, noctalia, hyprmon, plymouth-marchyo-theme, plus jylhis-design)
treefmt.nix         # Formatter config for treefmt-nix
devenv.nix          # Development shell configuration
devenv.yaml         # devenv inputs (nixpkgs pinned to same rev as flake.lock)
Justfile            # Task runner (check, fmt, build, update, verify)
statix.toml         # Statix linter configuration
modules/nixos/      # NixOS system-level modules (~31 modules)
modules/darwin/     # nix-darwin modules (imports shared options + generic modules)
modules/nix-on-droid/  # nix-on-droid (Android terminal): built via lib.mkNixOnDroidConfiguration; reuses generic git/shell modules; HM 24.05
modules/home/       # Home Manager user-level modules (~30 modules)
modules/generic/    # Shared modules imported by nixos, darwin, and home default.nix
packages/           # Custom Nix packages (hyprmon, plymouth-marchyo-theme)
tests/              # Evaluation-based test suite (no builds required)
disko/              # Disk partitioning configurations (not wired into flake outputs)
installer/          # ISO build configs (not wired into flake outputs)
templates/workstation/  # Developer workstation template
```

### Flake Outputs

- `lib.mkNixosSystem` / `lib.mkDarwinSystem` — **Batteries-included system builders** (recommended consumer entry point). Take `{ system, modules ? [], specialArgs ? {} }` and auto-select the correct nixpkgs, home-manager, nix-darwin, stylix, overlay and marchyo modules via the `inputsFor` selector in `outputs.nix` (x86_64-darwin → stable 26.05 trio; everything else → unstable). The reference `nixosConfigurations`/`darwinConfigurations` are built through these same builders. Also exported: `lib.mkNixOnDroidConfiguration` (batteries-included nix-on-droid builder, fixed to aarch64-linux; flows through the `droidInputs` grouping the way the others flow through `inputsFor`), `lib.mkHomeConfiguration`, `lib.inputsFor`, `lib.mkPkgs`
- `nixosModules.default` — Main NixOS module (includes Home Manager, Stylix, overlay)
- `nixosModules.home-manager` — Re-exported home-manager NixOS module
- `darwinModules.default` — nix-darwin module (includes Home Manager, overlay)
- `homeManagerModules.default` — Home Manager module only
- `homeManagerModules._1password` — 1Password Home Manager module
- `overlays.default` — Nixpkgs overlay (darwin-safe: Linux packages wrapped in `optionalAttrs`)
- `packages.{linux}.hyprmon` — Hyprland monitor management tool
- `packages.{linux}.plymouth-marchyo-theme` — Plymouth boot splash theme
- `legacyPackages.{system}` — Full nixpkgs with overlay applied, **system-aware** (x86_64-darwin → stable nixos-26.05, every other system → unstable; via `inputsFor`/`mkPkgs`)
- `templates.workstation` — Starter workstation template (uses nixpkgs passthrough)
- `apps.x86_64-linux.default` — QEMU VM runner with all features enabled
- `checks.{linux}.*` — Evaluation test suite
- `formatter.{system}` — treefmt wrapper (shared config with devenv)
- `nixosModules` / `darwinModules` / `homeManagerModules` / `nixOnDroidModules` — per-platform module sets
- `nixosConfigurations.{x86_64,aarch64}` — Reference NixOS configs (Linux, unstable), built through `lib.mkNixosSystem`; `x86_64` is built by CI and backs the VM runner
- `darwinConfigurations.{aarch64,x86_64}` — Reference nix-darwin configs, built through `lib.mkDarwinSystem`. `aarch64` rides unstable (`nix-darwin.lib.darwinSystem`, `home-manager`/`stylix` master); `x86_64` is pinned by the builder to stable nixos-26.05 (the builder injects `nixpkgs.pkgs = mkPkgs "x86_64-darwin"` + `mkForce`-cleared `nixpkgs.config`/`overlays`), uses `nix-darwin-stable.lib.darwinSystem` (nix-darwin-26.05) plus `home-manager-stable` + `stylix-stable` (both release-26.05) — all three perform a nixpkgs-release check (nix-darwin hard-fails, the others warn). `mkDarwinSystem` selects the matching nix-darwin/HM/stylix per system via the `inputsFor` selector and the `mkDarwinModules <hmModule>` helper, so each config bakes in the HM matching its nixpkgs
- `homeConfigurations.{x86_64-linux,aarch64-linux}` — Standalone Home Manager configs (Linux only)
- `nixOnDroidConfigurations.aarch64` — Reference Android terminal config, built through `lib.mkNixOnDroidConfiguration` (the same exported builder consumers use). Built impurely (`nix build --impure …activationPackage`): nix-on-droid uses `builtins.storePath`, so it cannot be evaluated in pure `nix flake check`. Coverage instead comes from `tests/eval/nix-on-droid.nix`, a pure check of the droid Home-Manager module (incl. the reused generic modules) against HM 24.05

Downstream consumers build with `marchyo.lib.mkNixosSystem` / `mkDarwinSystem`, which select the system-correct nixpkgs automatically — no separate nixpkgs input needed. The raw `marchyo.inputs.nixpkgs` passthrough remains available but is always **unstable**; for a system-correct, overlay-applied package set use `marchyo.legacyPackages.<system>`.

### Key Files

- `flake.nix` — Flake entry point. Imports `outputs.nix` with flake inputs, wraps per-system outputs with `forAllSystems`. Includes `flake-compat` as a non-flake input.
- `flake.lock` — **Single source of truth** for all pinned input revisions (nixpkgs, home-manager, stylix, etc.). `devenv.lock` syncs to this via `just update`.
- `outputs.nix` — All output logic. Takes `{ inputs }:`, returns nixosModules, darwinModules, homeManagerModules, overlays, templates, nixosConfigurations, the `lib` builders (`mkNixosSystem`/`mkDarwinSystem` via the `inputsFor` per-system selector + `mkPkgs`), and per-system constructors (mkPackages, mkChecks, mkFormatter, mkApps, legacyPackages).
- `default.nix` — Flake-compat shim. Uses `flake-compat` (pinned in `flake.lock`) to expose flake outputs to non-flake consumers (`nix-build`, devenv).
- `overlay.nix` — Nixpkgs overlay. Takes `{ inputs }:`, returns `final: prev:` function. All packages are Linux-only (wrapped in `lib.optionalAttrs stdenv.isLinux`).
- `lib/systems.nix` — Single source of truth for the system list. `flake.nix` imports `{ linux, darwin, all }` from here; adding/removing a system is a one-file change.
- `lib/discover-modules.nix` — Auto-discovery helper. Returns every `.nix` file directly under a given directory (excluding `default.nix`) plus any subdirectory containing `default.nix`. Used by `modules/{nixos,home}/default.nix` and `modules/nixos/options/default.nix`.
- `modules/nixos/options/` — `marchyo.*` option declarations split by namespace (users, defaults, feature-flags, performance, graphics, localization, theme, keyboard, tracking, deprecated). The directory's `default.nix` auto-imports every file.
- `modules/nixos/default.nix` — Auto-discovers every NixOS module via `lib/discover-modules.nix`. Module merging is order-independent at the option/config layer; use `mkBefore`/`mkAfter`/priorities if a specific merge order matters.
- `modules/darwin/default.nix` — **Manual** import list for nix-darwin modules. Curated subset (Wayland/systemd/desktop modules are NixOS-only and intentionally excluded). Imports `../nixos/options` for the shared option namespace.
- `modules/home/default.nix` — Auto-discovers every Home Manager module via `lib/discover-modules.nix`.
- `modules/nixos/input-migration.nix` — Assertions that enforce removal of deprecated `marchyo.inputMethod.*` options.
- `tests/default.nix` — Test suite entry point. Auto-discovers every file in `tests/eval/` and merges the attrsets they return; appends `lib-tests.nix`.
- `tests/lib.nix` — Shared test helpers (`testNixOS`, `withTestUser`, `minimalConfig`).
- `tests/eval/*.nix` — Per-feature evaluation tests. Each file receives helpers + `lib`/`pkgs`/`nixosModules`/`homeManagerModules` and returns an attrset of named tests.
- `tests/lib-tests.nix` — Unit tests for lib functions using `assertTest` helper.

## Module Patterns

### Standard NixOS module structure

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.feature.enable {
    # configuration here
  };
}
```

### Home Manager modules accessing NixOS config

Home Manager modules receive the NixOS config via `osConfig`:

```nix
{ config, lib, osConfig ? {}, ... }:
let
  cfg = osConfig.marchyo or {};
in
{ ... }
```

### Feature flag cascading

When `marchyo.desktop.enable = true`, the desktop-config module auto-enables related flags with `lib.mkDefault` so consumers can override:

```nix
marchyo.office.enable = lib.mkDefault true;
marchyo.media.enable = lib.mkDefault true;
```

### `lib.mkDefault` vs `lib.mkIf`

- `lib.mkDefault` — sets a value at lower priority; consumers can override it. Use for defaults that should be changeable.
- `lib.mkIf condition { ... }` — conditionally includes an entire config block. Use for feature-gated sections.
- `lib.mkMerge [ ... ]` — combines multiple conditional blocks safely when a module has several `mkIf` branches.

## Adding a New Module

1. Create the file in `modules/nixos/`, `modules/home/`, or `modules/generic/` — auto-discovery picks it up on the next eval (no import edit needed for nixos/home).
   - For `modules/darwin/`, add the import to `modules/darwin/default.nix` manually (curated subset).
2. Define any new options in a file under `modules/nixos/options/` — auto-discovery picks them up. Use an existing namespace file or create a new one (`mychunk.nix`) declaring `options.marchyo.<namespace>`.
3. Add an evaluation test in the appropriate `tests/eval/<feature>.nix`, or create a new file there:

```nix
{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
in
{
  eval-my-feature = testNixOS "my-feature" (withTestUser {
    marchyo.myFeature.enable = true;
  });
}
```

The `testNixOS` helper evaluates the NixOS config without building derivations. The `withTestUser` helper merges your config with a minimal bootable config (grub disabled, root filesystem, stateVersion). Tests are auto-discovered from `tests/eval/`.

## Testing

Tests in `tests/` are fast evaluation-based checks (no builds required). Two categories:
- **Module tests** (`tests/eval/*.nix`, auto-discovered): verify NixOS configs evaluate without errors for various feature combinations (minimal/feature-flags, themes, keyboard, graphics, defaults, tracking, hyprland config check).
- **Lib tests** (`tests/lib-tests.nix`): unit tests for lib functions using `assertTest` helper.

All changes must pass `just check` (or `nix flake check`).

## Cross-Module Data Flow

The keyboard/IME system is the most complex cross-module pattern:
1. `modules/nixos/options/keyboard.nix` — defines `marchyo.keyboard.layouts` accepting strings or attrsets
2. `modules/nixos/keyboard.nix` — normalizes layouts (string `"us"` → `{ layout = "us"; variant = ""; ime = null; }`) and sets XKB config
3. `modules/nixos/fcitx5.nix` — reads normalized layouts, detects which IME addons are needed, generates fcitx5 config
4. `modules/home/keyboard.nix` — extracts layout data into `home.keyboard` for Hyprland
5. `modules/home/hyprland.nix` — reads `osConfig.marchyo.graphics` for GPU-specific env vars and keyboard from `home.keyboard`

## Available Options Reference

### Feature Flags

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.desktop.enable` | `false` | Desktop (Hyprland, audio, bluetooth, fonts) |
| `marchyo.development.enable` | `false` | Dev tools (git, docker, virtualization) |
| `marchyo.media.enable` | `false` | Media apps (auto-enabled with desktop) |
| `marchyo.office.enable` | `false` | Office apps (auto-enabled with desktop) |

### User Configuration

```nix
marchyo.users.<username> = {
  enable = true;
  fullname = "Your Name";
  email = "your@email.com";
};
```

### Localization

| Option | Default | Example |
|--------|---------|---------|
| `marchyo.timezone` | `"Europe/Zurich"` | `"America/New_York"` |
| `marchyo.defaultLocale` | `"en_US.UTF-8"` | `"de_DE.UTF-8"` |

### Theming

```nix
marchyo.theme = {
  enable = true;
  variant = "dark";   # or "light"
};
```

Stylix `base16Scheme` is derived from the Jylhis Design System `tokens.json` by `modules/generic/jylhis-palette.nix` (`Jylhis Roast` for dark, `Jylhis Paper` for light), wired up in `modules/generic/stylix.nix`. To use a different base16 scheme, set `marchyo.theme.scheme = "<name>"` (a `base16-schemes` YAML) or override `stylix.base16Scheme` directly.

### Default Applications

When `marchyo.desktop.enable = true`, the `marchyo.defaults.*` options control which apps are installed and set as system defaults. Set any to `null` to skip management for that category.

```nix
marchyo.defaults = {
  browser = "google-chrome";      # brave, google-chrome, firefox, chromium
  editor = "jotain";              # emacs, jotain, vscode, vscodium, zed
  terminalEditor = "jotain";      # emacs, jotain, neovim, helix, nano
  videoPlayer = "mpv";            # mpv, vlc, celluloid
  audioPlayer = "mpv";            # mpv, cmus, vlc, amberol
  musicPlayer = "spotify-player"; # spotify-player, ncspot, spotify
  fileManager = "nautilus";       # nautilus, thunar
  terminalFileManager = "yazi";   # yazi, ranger, lf
  imageEditor = "pinta";         # pinta, gimp, krita
  email = "aerc";                # aerc, neomutt, gmail, outlook
};
```

`"jotain"` (the default editor/terminalEditor — [Jylhis's Emacs config](https://github.com/Jylhis/jotain)) installs via its `services.jotain` Home-Manager module (the `jotain` flake input, wired into `home-manager.sharedModules` in `outputs.nix`); the bridge `modules/home/jotain.nix` enables it when selected, and `modules/nixos/defaults.nix` sets `$EDITOR`/`$VISUAL` to its `jotain-editor`/`jotain-visual` wrappers (so jotain's own `defaultEditor` is left off). Web-based email (`"gmail"`, `"outlook"`) is externally managed — no package is installed by marchyo. The rest of the defaults implementation is in `modules/nixos/defaults.nix`. The default music (`spotify-player`) and mail (`aerc`) clients are TUIs; the music client launches in a floating terminal under Hyprland.

The TUI clients install via their Home-Manager `programs.*` modules (one file each under `modules/home/`: `spotify-player`, `ncspot`, `cmus`, `aerc`, `neomutt`), each gated on the matching `marchyo.defaults.*` selection — `defaults.nix` no longer adds them to `environment.systemPackages`. The Spotify GUI is always installed on x86_64 via `modules/nixos/media.nix`. `qalc` installs via `programs.qalculate` (`modules/home/qalculate.nix`).

### Keyboard & Input Methods

```nix
marchyo.keyboard = {
  layouts = [
    "us"
    { layout = "fi"; }
    { layout = "us"; variant = "intl"; }
    { layout = "cn"; ime = "pinyin"; }
    { layout = "jp"; ime = "mozc"; }
    { layout = "kr"; ime = "hangul"; }
  ];
  options = [ "grp:win_space_toggle" ];
  autoActivateIME = true;
  imeTriggerKey = [ "Super+I" ];
};
```

### Graphics (GPU)

```nix
marchyo.graphics = {
  vendors = [ "intel" ]; # "intel", "amd", "nvidia"
  nvidia.open = true;    # Open-source drivers (RTX 20xx+)
  prime = {
    enable = true;
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
    mode = "offload"; # "offload", "sync", "reverse-sync"
  };
};
```

To find GPU bus IDs: `lspci | grep -E 'VGA|3D'`

### Performance Tuning

`marchyo.performance.disableMitigations` (default `true`) disables CPU vulnerability mitigations.

`marchyo.performance.tuning.*` is opt-in kernel/sysctl/IO tuning, off by default. Enabling the master switch turns on the broadly-safe sub-toggles (`network`, `nvme`, `memory`); the aggressive ones (`hugePages`, `compute`) stay off unless set explicitly.

```nix
# Safe defaults (network + nvme + memory tuning):
marchyo.performance.tuning.enable = true;

# Compute/CUDA workstation — also opt into the aggressive toggles:
marchyo.performance.tuning = {
  enable = true;
  hugePages.enable = true;   # 2MiB THP — can hurt interactive/desktop latency
  compute.enable = true;     # relaxed PAM limits (memlock/rtprio) — trusted hosts only
};
```

The implementation is in `modules/nixos/performance-tuning.nix`. The CFS scheduler sysctls from older compute-tuning sets are deliberately omitted — they were removed in the CFS→EEVDF switch (kernel 6.6+) and only produce `systemd-sysctl` warnings on current kernels.

### AI (BYOK)

Marchyo ships a bring-your-own-key AI desktop. `marchyo.ai.enable` installs per-user AI clients wired to **OpenRouter**, plus task-based model routing, a local OpenViking context layer, MCP tools, and Agent Skills. The API key is supplied via a sops-nix secret (or any runtime file) and never enters the Nix store.

```nix
# Set owner: the sops-nix default secret is root-only 0400, unreadable by the user.
sops.secrets."openrouter-api-key".owner = "your-username";
marchyo.ai = {
  enable = true;
  openrouter.apiKeyFile = config.sops.secrets."openrouter-api-key".path; # required
};
```

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.ai.enable` | `false` | Enable BYOK AI tooling |
| `marchyo.ai.openrouter.apiKeyFile` | `null` | Runtime path to the API key (required when enabled) |
| `marchyo.ai.openrouter.baseUrl` | `https://openrouter.ai/api/v1` | OpenAI-compatible base URL |
| `marchyo.ai.openrouter.defaultModel` | `anthropic/claude-sonnet-4` | Model used when routing is off |
| `marchyo.ai.tooling.enable` | `true` | Install aichat / pi / claude-code |
| `marchyo.ai.routing.enable` | `true` | Task→model routing (`routing.tasks.<bucket>`, `routing.tools`) |
| `marchyo.ai.context.enable` | `false` | OpenViking (`ov`) local context layer |
| `marchyo.ai.skills.enable` | `true` | Install Agent Skills to all clients |
| `marchyo.ai.mcp.enable` | `true` | Wire MCP tools (mcp-nixos via uvx) |
| `marchyo.ai.local.enable` | `false` | Local inference — **not yet implemented** (fails an assertion) |

**Clients:** `aichat` (bound to `Super+A`), `pi` (Armin Ronacher's minimal coding agent, wired to OpenRouter via `~/.pi/agent/settings.json` + a provider extension), and `claude-code` (Anthropic-native — **not** wired to OpenRouter; sourced from `llm-agents.nix` with the Numtide binary cache). `aider`/`opencode` and the Emacs/gptel integration were removed.

**Routing:** `routing.tasks.<bucket> = { model; fallbacks; }` (buckets: frontier, everydayCoding, fast, reasoning, summarize, longContext, budget, local). Defaults are churn-resistant (`lib.mkDefault`; pin frontier/reasoning, lean on `openrouter/auto` + `:nitro`/`:floor`); slugs are starting points to verify against OpenRouter. The resolved policy is exported to `~/.config/marchyo/ai-routing.json`; each bucket is an aichat role.

**Implementation:** `modules/nixos/options/ai.nix` (options), `modules/nixos/ai.nix` (assertions), `modules/home/ai-tooling.nix` (clients + key export + routing + aichat/pi config), `modules/home/ai-context.nix` (OpenViking ov.conf), `modules/home/ai-skills.nix` (+ vendored `SKILL.md` under `modules/home/ai-skills/skills/`), `modules/home/ai-mcp.nix` (mcp-nixos). Packages: `packages/openviking/` (vendored from Jylhis/skills#56, real hashes), `packages/pi/` (npm tarball wrapper). The key is exported as `OPENROUTER_API_KEY` at interactive-shell startup (mirrors `tracking/claude-code.nix`). sops-nix and llm-agents.nix (claude-code + Numtide cache, applied via `overlayList` in `outputs.nix`) are flake inputs. Local inference (ollama) and the execution gateway are deferred.

### Omarchy-parity desktop extras (2026-07 batch)

Desktop-cascade features, each on by default with `marchyo.desktop.enable` and individually opt-out:

| Option | Default | Feature |
|--------|---------|---------|
| `marchyo.osd.enable` | `true` | SwayOSD volume/brightness overlay (`modules/home/swayosd.nix` + `modules/nixos/osd.nix` — udev rules + `video` group for backlight) |
| `marchyo.menus.enable` | `true` | `marchyo-power-menu` (`Super+Escape`) + `marchyo-menu` central menu (`Super+Alt+Space`), gum TUIs in floating ghostty (`modules/home/menus.nix`) |
| `marchyo.reminders.enable` | `true` | `marchyo-reminder-*` via transient systemd timers (`modules/home/utilities.nix`) |
| `marchyo.utilities.enable` | `true` | Quick-info notify, `marchyo-transcode`, `marchyo-share` (`modules/home/utilities.nix`) |
| `marchyo.screensaver.enable` | `true` | tte screensaver on 120s idle; keypress/mouse dismiss (`modules/home/screensaver.nix`) |
| `marchyo.security.firewall.enable` | `true` | `networking.firewall.enable` follows it at `mkDefault` (`modules/nixos/firewall.nix`) |
| `marchyo.security.fingerprint.enable` | `false` | `services.fprintd` (hyprlock follows automatically) |
| `marchyo.security.fido2.enable` | `false` | `security.pam.u2f` + libfido2; enroll with `pamu2fcfg` (`modules/nixos/security-auth.nix`) |
| `marchyo.services.tailscale.enable` | `true` | tailscale + trusted `tailscale0`, loose RP filter (`modules/nixos/tailscale.nix`) |
| `marchyo.services.localsend.enable` | `true` | LocalSend + firewall ports, Nautilus send action (`modules/nixos/localsend.nix`, `modules/home/nautilus.nix`) |
| `marchyo.power.hibernation.enable` | `false` | suspend-then-hibernate + hypridle idle-sleep; requires `resumeDevice` (`modules/nixos/hibernation.nix`) |

Other additions: universal clipboard `Super+C/V/X` via `sendshortcut` (toggle-floating moved `Super+V`→`Super+T`, `modules/home/hyprland.nix`); DND toggle `Super+Ctrl+comma` + waybar `custom/dnd` indicator (dismiss-all moved to `Super+Ctrl+Shift+comma`); monitor/connectivity/app-launch binds in `modules/home/omarchy-binds.nix`; runtime dark↔light switch `marchyo-theme-toggle` (`modules/home/theme-runtime.nix` — ephemeral overlay, resets on activation); `nixosModules.hardware.<profile>` re-exports nixos-hardware; `marchyo` CLI gained `update upgrade rollback gc diff debug`. See `docs/usage/hotkeys.mdx` for the full bind list.

### Dictation (voice-to-text)

`marchyo.dictation.enable` adds push-to-talk voice dictation to the Wayland desktop via [voxtype](https://voxtype.io) (nixpkgs `voxtype`, 0.6.x) + Whisper. Off by default (it needs a microphone and downloads a Whisper model).

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.dictation.enable` | `false` | Enable voxtype dictation (hold F9 to dictate + a Super+Ctrl+X toggle bind) |
| `marchyo.dictation.pushToTalk.enable` | `true` | Daemon evdev hold hotkey; adds dictation users to the `input` group |
| `marchyo.dictation.pushToTalk.key` | `"F9"` | evdev key held to record (e.g. `"SCROLLLOCK"`, `"PAUSE"`, `"F13"`) |
| `marchyo.dictation.pushToTalk.mode` | `"push_to_talk"` | `"push_to_talk"` (hold) or `"toggle"` (press to start/stop) |
| `marchyo.dictation.toggleKey` | `"SUPER CTRL, X"` | Hyprland bind for `voxtype record toggle`; `null` to unbind |
| `marchyo.dictation.gpu` | `true` | Use the Vulkan GPU build (`pkgs.voxtype-vulkan`); set false for the CPU-only `pkgs.voxtype` |
| `marchyo.dictation.model` | `"large-v3-turbo"` | Whisper model voxtype loads |
| `marchyo.dictation.language` | `"auto"` | Spoken language (`"auto"` detects per utterance; e.g. `"en"` to pin) |
| `marchyo.dictation.preloadModel` | `false` | Pre-download the model at activation instead of on first recording |
| `marchyo.dictation.indicator` | `true` | Waybar recording-state segment (streams `voxtype status --follow`) |
| `marchyo.dictation.notify` | `true` | Desktop notifications on record start/stop/transcription |
| `marchyo.dictation.audioFeedback` | `true` | Start/stop sound cues |
| `marchyo.dictation.statusWindow` | `true` | Super+Shift+H floating status window + its Hyprland rule |

When enabled, `modules/home/voxtype.nix` configures the **upstream** home-manager `services.voxtype` module (config at `~/.config/voxtype/config.toml`, a `voxtype` user service). It defaults `services.voxtype.package` to `pkgs.voxtype-vulkan` (the GPU/Vulkan Whisper build) rather than the stock CPU-only `pkgs.voxtype` — the stock package is a source build with no GPU engine compiled in, so it runs `large-v3-turbo` on CPU (very slow); the Vulkan build covers NVIDIA/AMD/Intel in one binary and falls back to CPU when no device is present. `marchyo.dictation.gpu = false` forces the CPU build. Recording is driven two ways (omarchy parity): the daemon's evdev push-to-talk hotkey (hold `pushToTalk.key`, default F9) and a `modules/home/hyprland.nix` bind (`toggleKey`, default `Super+Ctrl+X`) that runs `voxtype record toggle`; text is typed at the cursor with a clipboard fallback. The evdev hotkey needs `/dev/input` access, so `modules/nixos/dictation.nix` adds dictation users to the `input` group whenever `pushToTalk.enable` is set (a real privilege: any process the user runs can then observe keystrokes). Set `pushToTalk.enable = false` to rely only on the compositor toggle and skip the group membership. The old `Super+H` toggle bind was dropped. The Waybar segment's left-click toggles recording and right-click opens the status window (omarchy's model-picker/config-editor clicks do not apply to marchyo's declarative config). Options live in `modules/nixos/options/dictation.nix`. With `preloadModel = false`, the ~1.5 GB Whisper model downloads on first recording (a pure rebuild never blocks on the network); set it `true` to fetch it at activation via voxtype's model-loader service.

The four UI sub-options are on by default when dictation is enabled (each opt-out) and are the "full UI" layer on top of the headless daemon. voxtype's built-in `[output.notification]`/`[audio.feedback]` drive notifications and sound (no bespoke scripts). The Waybar `custom/voxtype` module (`modules/home/waybar.nix`) is the repo's **first streaming `exec` custom module**: `voxtype status --format json --follow` emits one JSON object per state change, read via `return-type = "json"`; its `class` field (idle/recording/transcribing) recolors the `#custom-voxtype` selector, and both the module definition and the `pkgs.voxtype` store-path reference are guarded by `lib.optionalAttrs` so a desktop without dictation never pulls voxtype into its closure. The status window reuses the music-player floating pattern (`--class=org.omarchy.voxtype` matched by the `floating-window` tag rule). `voxtype.nix` also now sets `services.voxtype.wayland.display = "wayland-1"` so the daemon unit has `WAYLAND_DISPLAY` + `wtype`/`wl-clipboard` for `output.mode = "type"` (previously it silently leaned on the clipboard fallback).

### Web apps (PWA windows + launch binds)

`marchyo.webapps.enable` (auto-enabled with `marchyo.desktop.enable` via `lib.mkDefault`; opt out with `marchyo.webapps.enable = false`) registers a list of sites as standalone browser "app" windows. Each entry in `marchyo.webapps.apps` becomes a freedesktop `.desktop` launcher (browser `--app=<url>`, no tabs/chrome) and, when it declares a `key`, an omarchy-style Hyprland keybinding.

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.webapps.enable` | `true` with desktop (mkDefault) | Register web apps as `.desktop` entries + launch binds |
| `marchyo.webapps.browser` | `null` | Chromium-family browser for `--app` mode; `null` follows `marchyo.defaults.browser`, else chromium |
| `marchyo.webapps.apps` | (ChatGPT, GitHub, YouTube, WhatsApp, Discord, Zoom, X, Google Photos, Google Calendar, Gmail) | List of `{ name; url; icon?; key?; modifiers?; }` |

Each app's submodule: `name` (label + slugified `.desktop` id), `url`, `icon` (default generic web icon), `key` (Hyprland key, `null` = no bind), `modifiers` (default `"SUPER SHIFT"`). The default set binds ChatGPT→`A`, GitHub→`G`, YouTube→`Y`, WhatsApp→`W`, Zoom→`Z`, X→`X`, Google Photos→`P`; **Discord, Google Calendar and Gmail have no default key** (`SUPER+SHIFT+D` is the scratchpad-move bind). Other taken `SUPER+SHIFT` letters to avoid: `C` (hyprpicker), `H` (dictation status), `I` (fcitx5), `O` (OCR), `S` (satty). Options in `modules/nixos/options/webapps.nix`; implementation in `modules/home/webapps.nix`. The browser is resolved once: explicit `webapps.browser` → chromium-based `marchyo.defaults.browser` → chromium (pulled into the profile via `home.packages` when the default browser isn't chromium-family, e.g. firefox). `modules/home/webapps.nix` contributes its launch binds by merging a `bindd` list into `wayland.windowManager.hyprland.settings` (the same list-merge pattern `modules/home/screenshot.nix` uses), reusing that resolved browser command. Note `modules/home/hyprland.nix` already carries window rules keyed on Chrome's generated app classes (e.g. `chrome-youtube.com__-Default`) for opacity/tag handling.

## Breaking Changes

### `marchyo.inputMethod.*` is REMOVED

These options have been removed. Using them causes a build failure. Migrate to `marchyo.keyboard.layouts`:

```nix
# Old (error):
marchyo.inputMethod.enable = true;
marchyo.inputMethod.enableCJK = true;

# New:
marchyo.keyboard.layouts = [
  "us"
  { layout = "cn"; ime = "pinyin"; }
];
```

### `marchyo.defaults.email = "thunderbird"` is REMOVED

`thunderbird` is no longer a valid `marchyo.defaults.email` value (the enum will
reject it at evaluation). Switch to a TUI client (`"aerc"`, `"neomutt"`) or a web
client (`"gmail"`, `"outlook"`). There is no in-place migration — Thunderbird's
native GUI is no longer managed by marchyo.

### Deprecated Options

- `marchyo.keyboard.variant` → use `{ layout = "us"; variant = "intl"; }` in layouts
- `marchyo.inputMethod.triggerKey` → **inert (has no effect)**, use `marchyo.keyboard.imeTriggerKey`
- `marchyo.inputMethod.enableCJK` → **inert (has no effect)**, add CJK entries to `marchyo.keyboard.layouts`

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

## Gotchas

- **Assertions for removed options**: `input-migration.nix` uses NixOS assertions to fail the build with migration instructions if anyone uses the removed `marchyo.inputMethod.*` options.
- **Deprecated options**: Some options emit warnings but still work. They are defined in `modules/nixos/options/deprecated.nix` (and `keyboard.nix`'s `variant` field) with deprecation notes in their descriptions.
- **Auto-discovery of modules**: Both `modules/nixos/default.nix` and `modules/home/default.nix` use `lib/discover-modules.nix` to import every `.nix` file in the directory plus any subdirectory containing a `default.nix`. Adding a new module is one file — no import-list edit needed. The NixOS module system merges options/config order-independently, so the dropped explicit ordering is safe; reach for `mkBefore`/`mkAfter`/priorities if a specific merge order ever matters.
- **Theme source of truth**: All theme assets (palette, ANSI 16, Hyprland colors, Waybar CSS, Mako config, GTK overrides, fzf colors, bat tmThemes, starship.toml, ghostty themes, hyprlock colors, console.colors) come from `pkgs.jylhis-design-src` (the unpacked `inputs.jylhis-design` flake input). The base16 mapping is computed from `tokens.json` by `modules/generic/jylhis-palette.nix`'s `mkPalette { variant, pkgs, lib }` helper. The upstream `${inputs.jylhis-design}/nix/home-manager-module.nix` is imported via `modules/home/jylhis-theme.nix` and writes ghostty themes, mako config, gtk CSS, starship.toml, and `FZF_DEFAULT_OPTS` directly. Only `marchyo.theme.scheme = "<name>"` overrides this and points at a `pkgs.base16-schemes` YAML instead.
- **Stylix target disablement**: marchyo overrides Stylix for surfaces it themes directly: `plymouth, hyprland, waybar, mako, ghostty, gtk, fzf, bat, hyprlock, console, starship`. See `modules/generic/theme.nix`. The remaining Stylix targets (qt, vicinae, kde, gnome, fontconfig, …) still receive base16-derived theming.
- **Plymouth splash is generated, not baked**: `packages/plymouth-marchyo-theme/` ships no logo/progress ONGs. At build time `package.nix` (a) rasterizes `logo.svg` into `logo.png` via `resvg`, (b) recolors the omarchy chrome ONGs (`entry`/`lock`/`bullet`) with ImageMagick, and (c) generates the solid `progress_bar`/`progress_box`, all colored from `tokens.json` for the selected `variant` (dark = Jylhis Roast, light = Jylhis Paper). The wordmark is the omarchy logo (`basecamp/omarchy` `logo.svg`, seven pixel-art letter paths) with the leading `o` moved to the end to spell "marchyo". That reorder is done by drawing the letter group twice inside the fixed `1215x285` viewBox and letting the SVG clip (copy A shifted `-165u` reads "marchy"; copy B shifted `+1080u` drops the `o` into the trailing slot). `modules/nixos/plymouth.nix` passes `marchyo.theme.variant` via `.override { variant = …; }`, so a variant flip retints the whole splash. Because plymouth runs at boot, the variant is baked at build (there is no runtime switch). `pkgs.plymouth-marchyo-theme` (overlay) defaults to `dark`.
- **`disko/` and `installer/` are starter snippets**: They are not wired into flake outputs. Copy the file you need into a downstream host configuration; they're versioned here as templates, not as a stable API.
- **`allowUnfree = true`**: Set globally in `legacyPackages` (via `outputs.nix`) and in test configs.
- **Formatter runs multiple tools**: `nix fmt` runs nixfmt, deadnix (unused vars), statix (linting), shellcheck, and yamlfmt via treefmt-nix (`treefmt.nix`). All must pass.
- **Nixpkgs pin sync**: `flake.lock` is the source of truth for all flake inputs. The devenv dev shell mirrors only the primary (unstable) `nixpkgs` and `treefmt-nix`; the stable set (`nixpkgs-stable`, `home-manager-stable`, `nix-darwin-stable`, `stylix-stable`), `nix-on-droid`, and `home-manager-droid` are flake-only and not mirrored into devenv. Run `just update` to bump inputs and sync `devenv.lock` to the same `nixpkgs` rev (`nix flake update` → extract rev → update `devenv.yaml` → `devenv update`). Run `just verify` to check the mirrored inputs are aligned. Renovate updates `flake.lock` independently via `lockFileMaintenance` but does not update `devenv.lock` — CI's `verify` job catches this drift so the PR will fail until `just update` is run to re-sync.
- **No standalone Home Manager tests**: The test suite only evaluates full NixOS configs (which include Home Manager). There are no tests that evaluate `homeManagerModules` in isolation.
- **Shared treefmt config**: `treefmt.nix` is the single source of truth for formatting. Both the flake formatter (`nix fmt`) and the devenv shell (`treefmt`) use it. devenv.yaml includes `treefmt-nix` as an input for this purpose.
- **Darwin module is intentionally minimal**: `darwinModules.default` imports the shared option namespace (`modules/nixos/options/`), nix-settings, and generic modules. Desktop/Wayland/systemd modules are NixOS-only. Unlike the auto-discovered NixOS/home lists, `modules/darwin/default.nix` is a hand-curated subset — keep it that way. The overlay is embedded but all packages are Linux-only (`optionalAttrs`).
- **Darwin wires a curated Home-Manager subset**: `modules/darwin/home.nix` sets up `home-manager.users` for marchyo users with a hand-picked darwin-safe list of `modules/home/*` (shell, packages, fzf, bat, direnv, ssh, ghostty, git, btop, starship + the generic modules). Never import `../home` wholesale on darwin — the full tree is Wayland/Hyprland-heavy. Darwin eval regressions are caught by the `testDarwinCheck` tests in `tests/eval/shell.nix` (nix-darwin evaluates on Linux CI via `lib.mkDarwinSystem`).
- **Bash is the default login shell everywhere**: NixOS sets `users.defaultUserShell = bashInteractive` (mkDefault, `modules/nixos/system.nix`); nix-on-droid sets `user.shell` to bash (zsh stays installed and configured). On macOS the switch is opt-in via `marchyo.users.<name>.uid` — nix-darwin only manages a login shell for `users.knownUsers`, which requires the account's exact uid (first macOS user is 501; a mismatch aborts activation). Without a uid, `modules/darwin/shell.nix` still registers bash 5.x in `/etc/shells` for a manual `chsh`.
- **Ghostty `ssh-env`/`ssh-terminfo` are deliberately enabled**: these shell-integration features are opt-in upstream (off by default). `modules/home/ghostty.nix` sets `shell-integration-features = "no-title,ssh-env,ssh-terminfo"` so SSH from Ghostty installs the xterm-ghostty terminfo on the remote (or falls back to `TERM=xterm-256color`) — don't "simplify" back to `no-title`; that breaks TUI apps over SSH. Inbound SSH is covered by `pkgs.ghostty.terminfo` in NixOS systemPackages (`modules/nixos/system.nix`) and `ghostty-bin.terminfo` on darwin (`outputs.nix`).
- **nix-on-droid is a first-class target but stays on HM 24.05**: nix-on-droid is built through `lib.mkNixOnDroidConfiguration` (parallel to `mkNixosSystem`/`mkDarwinSystem`), whose inputs flow through the `droidInputs` grouping in `outputs.nix` (the droid analog of `inputsFor`: nix-on-droid's own 2024-era nixpkgs + `home-manager-droid` at HM 24.05). `modules/nix-on-droid/` is a small tree — `default.nix` (droid system: `environment.packages`, `home-manager.config`) + `home.nix` — and `home.nix` reuses the HM-version-agnostic generic modules `../generic/git.nix` and `../generic/shell.nix` (both option-guarded; no `programs.git.settings`). Because the stack is still HM 24.05, do **not** import the marchyo `modules/home/*` modules (they need HM 25.05+), `../nixos/options`, or the marchyo overlay here — sharing the `marchyo.*` options namespace and stylix/theming is deferred to a future `home-manager-droid` bump. The full config is impure (`builtins.storePath`) — build with `just build-nix-on-droid` (`--impure`), never via pure `nix flake check`. The pure checks in `tests/eval/nix-on-droid.nix` exercise `home.nix` (incl. the reused generic modules) against HM 24.05 via `home-manager-droid`.
- **Nixpkgs passthrough**: Most flake inputs use `follows = "nixpkgs"` (the unstable primary). Exceptions: `nixpkgs-stable` (nixos-26.05) and its matching release-26.05 trio `home-manager-stable`/`nix-darwin-stable`/`stylix-stable` (all follow `nixpkgs-stable`, used only by `darwinConfigurations.x86_64`), and the nix-on-droid stack (`nix-on-droid` + `home-manager-droid`) which is pinned to its own 2024-era nixpkgs for internal consistency. Consumers should build via `marchyo.lib.mkNixosSystem` / `mkDarwinSystem`, which pick the system-correct nixpkgs through the `inputsFor` selector in `outputs.nix` (the single source of truth for the x86_64-darwin→stable decision). The raw `marchyo.inputs.nixpkgs` passthrough is always unstable; `marchyo.legacyPackages.<system>` is the system-aware, overlay-applied alternative. The workstation template demonstrates the builder pattern.
- **`site/`**: The Astro + Starlight website (landing page + docs), built with bun (in the dev shell) and deployed to Cloudflare Workers at https://marchyo.org. `just site-dev` / `just site-build` are the local entry points. Option documentation in `site/src/content/docs/docs/configuration/` should be kept in sync with the option declarations under `modules/nixos/options/`.
- **Package & option search (`/search/`)**: `site/src/pages/search.astro` searches three datasets. (1) Every `marchyo.*` **option** and (2) marchyo's own **packages** are searched client-side with Fuse.js over committed JSON in `site/src/data/{options,marchyo-packages}.json`. Those files are **generated by Nix** — the `site-search-data` package output in `outputs.nix` runs `nixosOptionsDoc` (filtered to `marchyo.*`, declaration paths rewritten to GitHub blob URLs) plus a package-meta walk. Regenerate with **`just site-data`**; the `search-data` job in `validate.yml` re-runs it and fails on a diff (the Cloudflare build is bun-only, so the JSON must be committed — same discipline as the lock-file rev-sync gate). (3) **All of nixpkgs** is served by a Cloudflare **D1 (SQLite FTS5)** index via the Worker route `/api/packages` (`site/worker/index.ts`); the site Worker is now an assets **+ script** Worker (`main` + `assets.binding` + `run_worker_first: ["/api/*"]` in `wrangler.jsonc`). The index is built from marchyo's **pinned** nixpkgs by `site/scripts/build-nixpkgs-index.sh` (`just site-index`) and loaded into D1 by `.github/workflows/nixpkgs-index.yml` (needs `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID`; create the DB once with `bunx wrangler d1 create marchyo-nixpkgs` and paste the `database_id` into `wrangler.jsonc`). Full-stack local dev: `just site-serve` (builds assets, seeds a local D1, runs `wrangler dev`). Until D1 is provisioned the nixpkgs tab degrades gracefully — marchyo options/packages still work.
- **hyprlock fingerprint auth is gated on fprintd**: `modules/home/hyprlock.nix` sets `auth."fingerprint:enabled" = osConfig.services.fprintd.enable or false`, not a hardcoded `true`. hyprlock's fprintd D-Bus backend aborts the process when the service is absent, so hardcoding it on breaks the lock screen on any desktop without a fingerprint reader — and marchyo never enables `services.fprintd` itself. A host that wants fingerprint unlock enables `services.fprintd` (e.g. via `nixos-hardware`) and the setting follows automatically. Don't "simplify" it back to `true`.
- **Tracking cascade auto-enables auditd**: `marchyo.tracking.enable = true` flips every sub-collector on via `lib.mkDefault`, including `system.auditd` (kernel audit subsystem with execve + per-user `~/.config` watch rules). To opt out without disabling the whole stack: `marchyo.tracking.system.auditd = false`. Tuning knobs live under `marchyo.tracking.system.auditd*` (backlog limit, failure mode, log rotation, ruleset lock, early-boot kernel cmdline) — see `modules/nixos/options/tracking.nix` and `modules/nixos/tracking/system.nix`.
- **Laurel audisp plugin**: `modules/nixos/tracking/laurel.nix` is enabled when `system.auditd && aggregation.enable` are both on. It runs as the `_laurel` system user, writes JSONL to `/var/log/laurel/audit.log`, and that file is added to the Vector source list in `modules/nixos/tracking/aggregation.nix`. Laurel is the only path by which kernel audit events reach the Loki sink — the raw `/var/log/audit/audit.log` is never read by Vector directly.
- **`config_changes` watch overlap**: When `system.auditd && system.fileWatch` are both on (the default cascade), `~/.config` is observed by both auditd's syscall watch and the per-user inotifywait service. Kept by design — they capture different things — but worth knowing if you see duplicated-looking events in aggregation output.
