# Available options reference

All custom options live under the `marchyo.*` namespace, declared under
`modules/nixos/options/`. This is the deep reference; the published, user-facing
version lives under `site/src/content/docs/docs/configuration/` (keep the two in
sync when changing option declarations).

## Feature Flags

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.desktop.enable` | `false` | Desktop (Hyprland, audio, bluetooth, fonts) |
| `marchyo.development.enable` | `false` | Dev tools (git, Podman, virtualization) |
| `marchyo.development.containers.backend` | `"podman"` | Container backend: `"podman"` (rootless) or `"docker"` (rootful daemon) |
| `marchyo.development.containers.dockerGroup` | `false` | Add users to the root-equivalent `docker` group (Docker backend only) |
| `marchyo.media.enable` | `false` | Media apps (auto-enabled with desktop) |
| `marchyo.office.enable` | `false` | Office apps (auto-enabled with desktop) |

## User Configuration

```nix
marchyo.users.<username> = {
  enable = true;
  fullname = "Your Name";
  email = "your@email.com";
};
```

## Localization

| Option | Default | Example |
|--------|---------|---------|
| `marchyo.timezone` | `"Europe/Zurich"` | `"America/New_York"` |
| `marchyo.defaultLocale` | `"en_US.UTF-8"` | `"de_DE.UTF-8"` |

## Theming

```nix
marchyo.theme = {
  enable = true;
  variant = "dark";   # or "light"
  fontScale = 1.25;   # global font-size multiplier (default 1.25; 1.0 = historical sizes)
};
```

`marchyo.theme.fontScale` is the single knob for font size system-wide: the math lives in `lib/font-scale.nix` (`round` = round-half-up; `terminusFont` snaps the TTY console to the nearest terminus PSF size). `modules/generic/stylix.nix` feeds it into `stylix.fonts.sizes.*`, which covers every still-Stylix'd surface (Qt/KDE/fontconfig apps, and GTK/GNOME apps via the enabled `gnome` target's dconf `interface font-name` — the disabled `gtk` target only governs Stylix's GTK CSS/settings.ini). The surfaces Stylix is fully disabled for read the scale from `osConfig.marchyo.theme.fontScale` and scale in their own modules (`ghostty`, `waybar` — CSS `font-size` + bar `height`, `mako`, `hyprlock`, `vicinae` — `font.normal.size`, `console`).

Stylix `base16Scheme` is derived from the Jylhis Design System `tokens.json` by `modules/generic/jylhis-palette.nix` (`Jylhis Field` for dark, `Jylhis Sheet` for light), wired up in `modules/generic/stylix.nix`. To use a different base16 scheme, set `marchyo.theme.scheme = "<name>"` (a `base16-schemes` YAML) or override `stylix.base16Scheme` directly.

## Default Applications

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

## Keyboard & Input Methods

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

## Graphics (GPU)

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

## Performance Tuning

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

## AI (BYOK)

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
| `marchyo.ai.tooling.enable` | `true` | Install pi / claude-code |
| `marchyo.ai.routing.enable` | `true` | Task→model routing (`routing.tasks.<bucket>`, `routing.tools`) |
| `marchyo.ai.context.enable` | `false` | OpenViking (`ov`) local context layer |
| `marchyo.ai.skills.enable` | `true` | Install Agent Skills to all clients |
| `marchyo.ai.mcp.enable` | `true` | Wire MCP tools (mcp-nixos via uvx) |
| `marchyo.ai.local.enable` | `false` | Local inference — **not yet implemented** (fails an assertion) |

**Clients:** `pi` (Armin Ronacher's minimal coding agent, wired to OpenRouter via `~/.pi/agent/settings.json` + a provider extension), and `claude-code` (Anthropic-native — **not** wired to OpenRouter; sourced from `llm-agents.nix` with the Numtide binary cache). `aider`/`opencode` and the Emacs/gptel integration were removed.

**Routing:** `routing.tasks.<bucket> = { model; fallbacks; }` (buckets: frontier, everydayCoding, fast, reasoning, summarize, longContext, budget, local). Defaults are churn-resistant (`lib.mkDefault`; pin frontier/reasoning, lean on `openrouter/auto` + `:nitro`/`:floor`); slugs are starting points to verify against OpenRouter. The resolved policy is exported to `~/.config/marchyo/ai-routing.json`.

**Implementation:** `modules/nixos/options/ai.nix` (options), `modules/nixos/ai.nix` (assertions), `modules/home/ai-tooling.nix` (clients + key export + routing + pi config), `modules/home/ai-context.nix` (OpenViking ov.conf), `modules/home/ai-skills.nix` (+ vendored `SKILL.md` under `modules/home/ai-skills/skills/`), `modules/home/ai-mcp.nix` (mcp-nixos). Packages: `packages/openviking/` (vendored from Jylhis/skills#56, real hashes), `packages/pi/` (npm tarball wrapper). The key is exported as `OPENROUTER_API_KEY` at interactive-shell startup. sops-nix and llm-agents.nix (claude-code + Numtide cache, applied via `overlayList` in `outputs.nix`) are flake inputs. Local inference (ollama) and the execution gateway are deferred.

## Omarchy-parity desktop extras (2026-07 batch)

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

Other additions: universal clipboard `Super+C/V/X` via `sendshortcut` (toggle-floating moved `Super+V`→`Super+T`, `modules/home/hyprland.nix`); DND toggle `Super+Ctrl+comma` + waybar `custom/dnd` indicator (dismiss-all moved to `Super+Ctrl+Shift+comma`); monitor/connectivity/app-launch binds in `modules/home/omarchy-binds.nix`; runtime theme switching via `marchyo theme` over the `marchyo.theme.themes` manifest (`modules/home/theme-runtime.nix` builds the assets — ephemeral overlay, resets on activation); `nixosModules.hardware.<profile>` re-exports nixos-hardware; the `marchyo` CLI is 1.0: the full omarchy-parity surface (system, theme/bg, 11 toggles, capture, menus/launch/power, reminder/info/transcode/share/font, install/webapp/security, runtime restore, completions+man) with the former `marchyo-*` helper scripts absorbed into TypeScript (`packages/marchyo-cli`) and every bind/menu/waybar action dispatching `marchyo …`. Command names/flags/exit codes are frozen until 2.0 (contract snapshot tests); `cli-state.json`/`runtime.json` stay internal. Full reference: `site/src/content/docs/docs/usage/cli.mdx`. See `docs/usage/hotkeys.mdx` for the full bind list.

## Dictation (voice-to-text)

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

## Application launcher (Vicinae)

`marchyo.launcher.enable` (auto-enabled with `marchyo.desktop.enable` via `lib.mkDefault`) runs [Vicinae](https://vicinae.com) as a user service: `Super+R` toggles it, `Super+period` is the emoji picker, `Super+Ctrl+V` clipboard history.

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.launcher.enable` | `true` with desktop (mkDefault) | Enable the Vicinae launcher |
| `marchyo.launcher.keybinding` | `"emacs"` | In-launcher navigation: `"default"`, `"vim"`, `"emacs"` |
| `marchyo.launcher.inputServer.enable` | `true` | `cap_dac_override` wrapper for `/dev/uinput` keystroke injection |
| `marchyo.launcher.telemetry.enable` | `false` | Vicinae's usage telemetry (upstream enables it) |
| `marchyo.launcher.declutter` | `true` | Hide Donate / Report a Bug / About / Set Theme from root search |
| `marchyo.launcher.settings` | `{}` | Freeform passthrough merged into `programs.vicinae.settings` |

Options in `modules/nixos/options/launcher.nix` (platform-neutral — darwin imports this directory); implementation split across `modules/nixos/launcher.nix` (the setcap wrapper gate) and `modules/home/vicinae.nix` (settings, themes, user service). Every settings leaf is `lib.mkDefault`, so `marchyo.launcher.settings` overrides with plain values. Marchyo departs from three upstream defaults for privacy: `telemetry.system_info` off (this also empties the "What's New" section, whose only current item is the telemetry notice), `favicon_service = "none"` (upstream's `"twenty"` sends every bookmark/quicklink domain to a third party), and `encrypt_sensitive_data` on (upstream leaves it off on Linux). Deliberately not wired: `extensions`, `settingOverrides`, `enableSoulver`, `global_shortcuts.toggle`, `favorites`/`fallbacks`, window geometry, and the per-provider `preferences` trees — reach for `programs.vicinae.*` directly. Coverage is `tests/eval/launcher.nix`. See also the four vicinae gotchas in [gotchas.md](gotchas.md) (dead config keys, two-sided input-server wiring, theming, emacs keybind collisions).

## Web apps (PWA windows + launch binds)

`marchyo.webapps.enable` (auto-enabled with `marchyo.desktop.enable` via `lib.mkDefault`; opt out with `marchyo.webapps.enable = false`) registers a list of sites as standalone browser "app" windows. Each entry in `marchyo.webapps.apps` becomes a freedesktop `.desktop` launcher (browser `--app=<url>`, no tabs/chrome) and, when it declares a `key`, an omarchy-style Hyprland keybinding.

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.webapps.enable` | `true` with desktop (mkDefault) | Register web apps as `.desktop` entries + launch binds |
| `marchyo.webapps.browser` | `null` | Chromium-family browser for `--app` mode; `null` follows `marchyo.defaults.browser`, else chromium |
| `marchyo.webapps.apps` | (ChatGPT, GitHub, YouTube, WhatsApp, Discord, Zoom, X, Google Photos, Google Calendar, Gmail) | List of `{ name; url; icon?; key?; modifiers?; }` |

Each app's submodule: `name` (label + slugified `.desktop` id), `url`, `icon` (default generic web icon), `key` (Hyprland key, `null` = no bind), `modifiers` (default `"SUPER SHIFT"`). The default set binds ChatGPT→`A`, GitHub→`G`, YouTube→`Y`, WhatsApp→`W`, Zoom→`Z`, X→`X`, Google Photos→`P`; **Discord, Google Calendar and Gmail have no default key** (`SUPER+SHIFT+D` is the scratchpad-move bind). Other taken `SUPER+SHIFT` letters to avoid: `C` (hyprpicker), `H` (dictation status), `I` (fcitx5), `O` (OCR), `S` (satty). Options in `modules/nixos/options/webapps.nix`; implementation in `modules/home/webapps.nix`. The browser is resolved once: explicit `webapps.browser` → chromium-based `marchyo.defaults.browser` → chromium (pulled into the profile via `home.packages` when the default browser isn't chromium-family, e.g. firefox). `modules/home/webapps.nix` contributes its launch binds by merging a `bindd` list into `wayland.windowManager.hyprland.settings` (the same list-merge pattern `modules/home/screenshot.nix` uses), reusing that resolved browser command. Note `modules/home/hyprland.nix` already carries window rules keyed on Chrome's generated app classes (e.g. `chrome-youtube.com__-Default`) for opacity/tag handling.

## Breaking Changes

### `marchyo.defaults.email = "thunderbird"` is REMOVED

`thunderbird` is no longer a valid `marchyo.defaults.email` value (the enum will
reject it at evaluation). Switch to a TUI client (`"aerc"`, `"neomutt"`) or a web
client (`"gmail"`, `"outlook"`). There is no in-place migration — Thunderbird's
native GUI is no longer managed by marchyo.

### Deprecated Options

- `marchyo.keyboard.variant` → use `{ layout = "us"; variant = "intl"; }` in layouts
