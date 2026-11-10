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
| `marchyo.shell.enable` | `true` with desktop (mkDefault) | Unified Quickshell shell, the default desktop shell (cascaded in `modules/nixos/desktop-config.nix`). `false` keeps the discrete hyprlock and hyprpolkitagent and drops the bar, OSD and notifications |

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
  followWallpaper = false;  # true: `marchyo bg set/next` also generate a matugen theme from the image
};
```

`marchyo.theme.fontScale` is the single knob for font size system-wide: the math lives in `lib/font-scale.nix` (`round` = round-half-up; `terminusFont` snaps the TTY console to the nearest terminus PSF size). The GNOME interface fonts (dconf `font-name`/`document-font-name`/`monospace-font-name`) scale in `modules/home/jylhis-theme.nix` — Qt apps read them through the gtk3 platform theme. Every other surface reads the scale from `osConfig.marchyo.theme.fontScale` and scales in its own module (`ghostty`, the shell, `hyprlock`, `console`, the launcher, Emacs's default face).

The base16 slot palette is derived from the Jylhis Design System tokens vendored in `lib/design` by `modules/generic/jylhis-palette.nix` (`Jylhis Dark` for dark, `Jylhis Light` for light) and consumed by `modules/generic/theme-slots.nix` (plus the runtime theme dirs). To use a different base16 scheme, set `marchyo.theme.scheme = "<name>"` (a tinted-schemes catalog YAML); the slot surfaces and runtime switching follow it.

### Shell appearance scale axes

`marchyo.theme.appearance.*` are palette-independent scale multipliers and style switches over the base design tokens, affecting only the Quickshell shell (`marchyo.shell`). The scale axes default neutral; the style axes are `floatingBar` (default off: a flush strip) and the Caelestia-inspired `surfaceAlpha` (default on). Baked into `Commons/Style.qml` at build time via the `marchyo-shell` override.

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.theme.appearance.floatingBar` | `false` | Float the bar as a detached rounded pill with gaps to the screen edges instead of the full-width strip; also lifts panels, toasts, OSD, launcher, and tooltips off the bar geometry |
| `marchyo.theme.appearance.surfaceAlpha` | `0.85` | Opacity of shell surfaces (bar, panels, toasts, OSD). Below `1` enables the Hyprland blur effect and blur layer rules for the shell's namespaces (glass look); `1.0` restores fully opaque surfaces and keeps blur off |
| `marchyo.theme.appearance.cornerRadiusScale` | `1.0` | Multiplier on shell corner radii (panels, OSD); `0.0` squares every corner |
| `marchyo.theme.appearance.uiScale` | `1.0` | Multiplier on shell geometry (bar height, spacing, sizes) on top of `fontScale`, without changing font sizes |
| `marchyo.theme.appearance.animationSpeed` | `1.0` | Shell animation speed (higher = faster); exposed as `Style.animationDuration` |
| `marchyo.theme.appearance.reduceMotion` | `true` in a VM guest, else `false` | No Hyprland animations, blur or shadows, opaque windows, and shell animation duration 0 |
| `marchyo.theme.appearance.highContrast` | `false` | Thicker panel/notification borders for higher-contrast chrome (`Style.highContrast` / `Style.borderWidth`) |

## Default Applications

When `marchyo.desktop.enable = true`, the `marchyo.defaults.*` options control which apps are installed and set as system defaults. Set any to `null` to skip management for that category.

```nix
marchyo.defaults = {
  browser = "google-chrome";      # brave, google-chrome, firefox, chromium
  editor = "emacs";                # emacs, vscode, vscodium, zed
  terminalEditor = "emacs";        # emacs, neovim, helix, nano
  videoPlayer = "mpv";            # mpv, vlc, celluloid
  audioPlayer = "mpv";            # mpv, vlc, amberol
  musicPlayer = "spotify-player"; # spotify-player, spotify
  fileManager = "nautilus";       # nautilus, thunar
  terminalFileManager = "yazi";   # yazi, ranger, lf
  imageEditor = "pinta";         # pinta, gimp, krita
  email = "aerc";                # aerc, gmail, outlook
};
```

`"emacs"` (the default editor/terminalEditor) installs `pkgs.emacs` and sets `$VISUAL`/`$EDITOR` to `emacsclient` invocations with plain-Emacs fallbacks; see `modules/nixos/defaults.nix`. Web-based email (`"gmail"`, `"outlook"`) is externally managed — no package is installed by marchyo. The rest of the defaults implementation is in `modules/nixos/defaults.nix`. The default music (`spotify-player`) and mail (`aerc`) clients are TUIs; the music client launches in a floating terminal under Hyprland.

The TUI clients install via their Home-Manager `programs.*` modules (one file each under `modules/home/`: `spotify-player`, `aerc`), each gated on the matching `marchyo.defaults.*` selection — `defaults.nix` no longer adds them to `environment.systemPackages`. The Spotify GUI is always installed on x86_64 via `modules/nixos/media.nix`. `qalc` installs via `programs.qalculate` (`modules/home/qalculate.nix`).

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
  autoActivateIME = false;
  imeTriggerKey = [ "Super+I" ];
};
```

## Graphics (GPU)

```nix
marchyo.graphics = {
  vendors = [ "intel" "nvidia" ]; # "intel", "amd", "nvidia"
  primary = "intel"; # required with several vendors (PRIME defaults it)
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

`marchyo.performance.tuning.*` is opt-in kernel/sysctl/IO tuning, off by default. Enabling the master switch turns on the broadly-safe sub-toggles (`network`, `nvme`, `memory`, `hugePages`); the aggressive `compute` toggle stays off unless set explicitly.

```nix
# Safe defaults (network + nvme + memory + madvise THP):
marchyo.performance.tuning.enable = true;

# Compute/CUDA workstation: also opt into the aggressive toggle:
marchyo.performance.tuning = {
  enable = true;
  compute.enable = true;     # relaxed PAM limits (memlock/rtprio) — trusted hosts only
};
```

The implementation is in `modules/nixos/performance-tuning.nix`. The CFS scheduler sysctls from older compute-tuning sets are deliberately omitted — they were removed in the CFS→EEVDF switch (kernel 6.6+) and only produce `systemd-sysctl` warnings on current kernels.

## Desktop extras

Desktop-cascade features, each on by default with `marchyo.desktop.enable` and individually opt-out:

| Option | Default | Feature |
|--------|---------|---------|
| `marchyo.menus.enable` | `true` | `marchyo-power-menu` (`Super+Escape`) + `marchyo-menu` central menu (`Super+Alt+Space`), gum TUIs in floating ghostty (`modules/home/menus.nix`) |
| `marchyo.reminders.enable` | `true` | `marchyo-reminder-*` via transient systemd timers (`modules/home/utilities.nix`) |
| `marchyo.utilities.enable` | `true` | Quick-info notify, `marchyo-transcode`, and `marchyo share` (LocalSend sender, Trigger submenu of `marchyo menu`) (`modules/home/utilities.nix`) |
| `marchyo.screensaver.enable` | `true` | tte screensaver on 120s idle; keypress/mouse dismiss (`modules/home/screensaver.nix`) |
| `marchyo.security.fingerprint.enable` | `false` | `services.fprintd` (the hyprlock fallback follows automatically) |
| `marchyo.security.fido2.enable` | `false` | `security.pam.u2f` + libfido2; enroll with `pamu2fcfg` (`modules/nixos/security-auth.nix`) |
| `services.tailscale.enable` | `true` (marchyo `mkDefault`) | tailscale + trusted `tailscale0`, loose RP filter (`modules/nixos/tailscale.nix`) |
| `marchyo.services.tailscale.operator` | first enabled marchyo user with desktop + shell, else `null` | `tailscale set --operator` via `services.tailscale.extraSetFlags`, so the shell's Control Center tile can connect/disconnect (`modules/nixos/tailscale.nix`) |
| `programs.localsend.enable` | `marchyo.desktop.enable` (marchyo `mkDefault`) | LocalSend app, Nautilus send action (`modules/nixos/localsend.nix`, `modules/home/nautilus.nix`) |
| `programs.localsend.openFirewall` | `true` (upstream) | Open TCP+UDP 53317 so other devices can discover and send to this host; `marchyo share` sends either way |

Hyprland binds are one table in `lib/keybinds.nix`, rendered into `wayland.windowManager.hyprland.settings.bind` by `modules/home/keybinds.nix`. Feature modules add commands and keyed web apps through `marchyo.keybinds.commands` and `marchyo.keybinds.webapps`. Runtime theme switching (`marchyo theme`) runs over the `marchyo.theme.themes` manifest (`modules/home/theme-runtime.nix` builds the assets as an ephemeral overlay that resets on activation). Every bind and menu action dispatches `marchyo …` (`packages/marchyo-cli`); command names, flags and exit codes are frozen until 2.0 (contract snapshot tests), and `cli-state.json`/`runtime.json` stay internal. Full references: `manual/08-the-marchyo-cli.md` and `manual/07-hotkeys.md`.

## Additional options

Options not covered by the sections above, grouped by namespace. Each is declared in the file named after its namespace under `modules/nixos/options/`; the option description there is the full reference.

### System, localization and tools

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.autoTimezone.enable` | `false` | Update the timezone from the location (`services.automatic-timezoned` via geoclue2); overrides the static `marchyo.timezone` |
| `marchyo.language` | `"en"` | Display language of the shell and CLI strings (a code from `shell/i18n/locales.json`); does not change the system `LANG` |
| `marchyo.cli.enable` | `true` | Install the `marchyo` user CLI system-wide |
| `marchyo.tmux.enable` | `marchyo.development.enable` | Themed tmux: mouse, true colour, vi copy mode, 1-based windows, Marchyo colours that follow `marchyo theme` |
| `marchyo.bees.enable` | `false` | Block-level btrfs deduplication through `services.beesd` |
| `marchyo.bees.filesystems` | `{}` | btrfs filesystems to deduplicate, keyed by name; each entry forwards to `services.beesd.filesystems.<name>` (`spec` is required) |
| `marchyo.emacs.enable` | `false` | Emacs daemon and Hyprland integration |
| `marchyo.emacs.package` | `pkgs.emacs-pgtk` | Emacs package of the user daemon |
| `marchyo.emacs.eventListener.enable` | `true` | Run Emacs hooks on Hyprland workspace and window events |
| `marchyo.emacs.everywhere.enable` | `true` | `SUPER+CTRL+E` captures the focused text field into an Emacs frame |
| `marchyo.emacs.orgProtocol.enable` | `true` | Register `org-protocol` and bind `SUPER+SHIFT+T` to `org-capture` |
| `marchyo.emacs.scratchpad.enable` | `true` | `SUPER+Z` toggles an `emacsclient` scratchpad frame |
| `marchyo.emacs.windmove.enable` | `true` | `SUPER+ALT+H/J/K/L` moves focus through Emacs windows, then Hyprland windows |
| `marchyo.hardware.camera.waitForAccess` | `true` | Delay WirePlumber's start at login (at most 5 s) until the session can open the camera media devices |
| `marchyo.hardware.ddc.enable` | `true` with desktop | DDC/CI control of external monitors through ddcutil (i2c-dev, udev rules, user groups) |

### Defaults

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.defaults.aiAgent` | `null` | `"claude-code"`, `"codex"` or `"opencode"`: with `marchyo.development.enable`, installs that CLI and sets `$AI_AGENT` |
| `marchyo.defaults.excludePackages` | `[]` | Packages to drop from marchyo's default bundles (`modules/nixos/packages.nix`) |

### Graphics

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.graphics.nvidia.generation` | `"turing-or-newer"` | `"turing-or-newer"` (open kernel modules, direct VA-API backend) or `"pre-turing"` (Maxwell, Pascal, Volta: closed modules) |
| `marchyo.graphics.prime.amdgpuBusId` | `""` | PCI bus ID of the AMD GPU, for PRIME and Hyprland's GPU list |
| `marchyo.graphics.prime.integratedOnlySpecialisation` | `false` | Add an `integrated-only` boot specialisation with PRIME and the NVIDIA modules off |
| `marchyo.graphics.amd.vaapi.enable` | `true` | Mesa radeonsi for VA-API and VDPAU (the driver variables apply when AMD is `primary`) |
| `marchyo.graphics.amd.rocm.enable` | `false` | ROCm compute stack (HIP, OpenCL); adds users to `render` and `video` |
| `marchyo.graphics.amd.rocm.hsaOverrideGfxVersion` | `null` | `HSA_OVERRIDE_GFX_VERSION` for GPUs ROCm does not officially support (e.g. `"10.3.0"`) |

### Keyboard

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.keyboard.backlight.enable` | `true` | Bind the keyboard backlight keys to `marchyo brightness --keyboard`; inert without a `*kbd_backlight*` LED |
| `marchyo.keyboard.composeKey` | `"menu"` | XKB Compose key (Hyprland only); `null` for none |
| `marchyo.keyboard.fnMode` | `null` | Default top-row behaviour for drivers with a host-side Fn lock: `"media"` or `"function"`; `null` leaves the firmware setting |

### Network and notifications

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.network.connectivityCheck.enable` | `true` | Periodic NetworkManager connectivity check; lets the shell detect captive portals (`marchyo network portal`) |
| `marchyo.network.connectivityCheck.interval` | `300` | Seconds between checks |
| `marchyo.network.connectivityCheck.uri` | `"http://nmcheck.gnome.org/check_network_status.txt"` | Plain-HTTP endpoint requested for the check |
| `marchyo.network.connectivityCheck.response` | `"NetworkManager is online"` | Text the endpoint returns when online; empty accepts any answer with the `X-NetworkManager-Status: online` header |
| `marchyo.notifications.detectCodes` | `true` | Detect verification codes: the toast gets a Copy button and passes do-not-disturb |
| `marchyo.notifications.passApps` | `["marchyo"]` | Application names (exact, case-insensitive) whose notifications pass do-not-disturb; critical ones always pass |
| `marchyo.notifications.stackBySender` | `true` | Group visible toasts into decks by sender; identical repeats collapse into one toast with a count |

### Performance and power

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.performance.kyber.enable` | `true` | kyber I/O scheduler on whole non-rotational, non-zoned disks |
| `marchyo.performance.tuning.network.enable` | `tuning.enable` | TCP Fast Open, window scaling, larger socket buffers |
| `marchyo.performance.tuning.nvme.enable` | `tuning.enable` | mq-deadline scheduler, larger read-ahead and request size for NVMe |
| `marchyo.performance.tuning.memory.enable` | `tuning.enable` | Lower swappiness, cached metadata, absolute dirty-page thresholds |
| `marchyo.performance.tuning.memory.dirtyBytes` | `268435456` | `vm.dirty_bytes` |
| `marchyo.performance.tuning.memory.dirtyBackgroundBytes` | `67108864` | `vm.dirty_background_bytes` |
| `marchyo.performance.tuning.hugePages.enable` | `tuning.enable` | Transparent huge pages on request (`madvise`) |
| `marchyo.performance.tuning.compute.enable` | `false` | Relaxed PAM limits and RT scheduling for trusted compute hosts |
| `marchyo.power.lid.onAC` | `"suspend"` | Lid-close action on external power |
| `marchyo.power.lid.onBattery` | `"suspend"` | Lid-close action on battery |
| `marchyo.power.lid.docked` | `"ignore"` | Lid-close action while docked or with another display connected |
| `marchyo.power.hibernation.enable` | `false` | Suspend actions become suspend-then-hibernate and the power menus show Hibernate; needs swap at least the size of RAM and `boot.resumeDevice` |
| `marchyo.power.hibernation.suspendThenHibernateDelay` | `"2h"` | Sleep time before hibernating (`HibernateDelaySec`) |

### Security

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.security.ssh.enable` | `false` | OpenSSH server, key-only; evaluation fails unless every admitted login user has an authorized key |
| `marchyo.security.ssh.users` | `[]` | Non-`wheel` users that also need an authorized key (`wheel` members are always checked) |
| `marchyo.security.ssh.allowNoKeys` | `false` | Skip the authorized-key check for keys that appear at runtime |
| `marchyo.security.sudo.timestampTimeout` | `10` | Minutes sudo remembers a password (`0` always asks, negative never expires) |

### Shell, menu and monitors

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.shell.settings` | `{}` | Runtime shell configuration, serialized to the read-only `~/.config/marchyo/shell.json` (`bar.layout`, `bar.style`, `idle`, `clock.seconds`, `battery.percentage`, `caffeine.autoVideo`, `monitors.<output>`) |
| `marchyo.shell.plugins` | `[]` | `pkgs.mkMarchyoShellPlugin` derivations baked into the shell (`bar-widget`, `daemon`, `launcher`) |
| `marchyo.shell.extraPlugins` | `[]` | Pinned git plugin specs appended to `plugins`; `marchyo plugin add` persists here |
| `marchyo.shell.diskWarnPercent` | `10` | Free-space percentage of the Nix store filesystem at or below which the disk bar widget appears |
| `marchyo.menu.entries` | `{}` | Entries of the shell command menu, keyed by dotted id (parents must exist); overrides single fields of the default tree in `lib/menu-entries.nix` |
| `marchyo.monitors` | `[]` | Declarative monitor layout rendered into Hyprland's `monitor` table; each entry takes `output`, `enable`, `mode`, `position`, `scale`, `transform`, `vrr`, `extraSettings`. Empty keeps one catch-all auto-detect rule |
| `marchyo.monitorPanel.persist` | `true` | Load the display panel's saved settings (`$XDG_STATE_HOME/marchyo/monitors/settings`) after `marchyo.monitors`; `marchyo monitor reset` clears them |
| `marchyo.workspaces.perMonitor` | `true` | Each monitor owns a block of ten workspace ids (1-10, 11-20, …) |

### Theme

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.theme.scheme` | `null` | tinted-schemes base16 scheme name that replaces the Jylhis palette |
| `marchyo.theme.themes` | Jylhis pair | Themes pre-built for runtime switching: `"jylhis-dark"`, `"jylhis-light"`, a catalog scheme name, or an inline base16 theme |
| `marchyo.theme.wallpaper.enable` | `true` | Generated Marchyo grid wallpaper |
| `marchyo.theme.wallpaper.package` | `pkgs.marchyo-wallpapers` | Package providing the wallpaper assets |
| `marchyo.theme.appearance.animations` | `"auto"` | Hyprland animations: `"auto"` (off in a VM or with `reduceMotion`), `"on"`, `"off"`; switch live with `marchyo toggle animations` |
| `marchyo.theme.appearance.corners` | `"theme"` | Window corners: `"theme"` (square grid), `"sharp"`, `"rounded"`; live with `marchyo theme corners` |
| `marchyo.theme.appearance.gaps` | `false` | 5 px between tiled windows and 10 px to the screen edge; live with `marchyo theme gaps` |
| `marchyo.theme.appearance.transparency` | `"opaque"` | `"opaque"`, `"transparent"` or `"glassy"` (translucent plus blur); live with `marchyo theme transparency` |

### Web apps

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.webapps.extraApps` | `[]` | Apps appended to `apps`; `marchyo webapp add` persists here |
| `marchyo.webapps.presets.google.enable` | `false` | Google Workspace apps (Gmail, Calendar, Drive, Docs, Sheets, Slides, Meet, Chat, Keep, Forms, Sites, Contacts, Tasks), no launch keys |
| `marchyo.webapps.presets.m365.enable` | `false` | Microsoft 365 apps (Outlook, Word, Excel, PowerPoint, Teams, OneDrive), no launch keys |
| `marchyo.webapps.presets.notion.enable` | `false` | Notion: `notion-app-enhanced` on x86_64-linux with `allowUnfree`, else a web app |

## Dictation (voice-to-text)

`marchyo.dictation.enable` adds push-to-talk voice dictation to the Wayland desktop via [voxtype](https://voxtype.io) (nixpkgs `voxtype`, 1.x) + Whisper. Off by default (it needs a microphone and downloads a Whisper model).

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.dictation.enable` | `false` | Enable dictation (hold F9 to dictate + a Super+Ctrl+X toggle bind) |
| `marchyo.dictation.backend` | `"voxtype"` | `voxtype` (the only backend); see `modules/home/voxtype.nix` |
| `marchyo.dictation.pushToTalk.enable` | `true` | Daemon evdev hold hotkey; adds dictation users to the `input` group |
| `marchyo.dictation.pushToTalk.key` | `"F9"` | evdev key held to record (e.g. `"SCROLLLOCK"`, `"PAUSE"`, `"F13"`) |
| `marchyo.dictation.pushToTalk.mode` | `"push_to_talk"` | `"push_to_talk"` (hold) or `"toggle"` (press to start/stop) |
| `marchyo.dictation.toggleKey` | `"SUPER + CTRL + X"` | Hyprland bind for `marchyo dictation toggle`; `null` to unbind |
| `marchyo.dictation.gpu` | `true` | Use the Vulkan GPU build (`pkgs.voxtype-vulkan`); set false for the CPU-only `pkgs.voxtype` |
| `marchyo.dictation.model` | `"large-v3-turbo"` | Whisper model voxtype loads |
| `marchyo.dictation.language` | `"auto"` | Spoken language (`"auto"` detects per utterance; e.g. `"en"` to pin) |
| `marchyo.dictation.preloadModel` | `false` | Pre-download the model at activation instead of on first recording |
| `marchyo.dictation.onDemandModel` | `false` | Load the model on record start and unload after transcription (frees VRAM) instead of keeping it resident |
| `marchyo.dictation.gpuIsolation` | `false` | GPU memory isolation so a discrete GPU can sleep between recordings (hybrid-graphics laptops) |
| `marchyo.dictation.spokenPunctuation` | `false` | Convert spoken punctuation words to symbols (say "period" → `.`) |
| `marchyo.dictation.replacements` | `{}` | Case-insensitive transcript substitutions for domain jargon (spoken form → typed text) |
| `marchyo.dictation.silenceGate.enable` | `true` | Drop recordings with no detected speech before transcription (voxtype `[vad]`), so silence does not hallucinate text |
| `marchyo.dictation.silenceGate.backend` | `"energy"` | `"energy"` (RMS over 20 ms frames, no model) or `"whisper"` (Silero, needs `ggml-silero-vad.bin` via `voxtype setup vad`) |
| `marchyo.dictation.silenceGate.threshold` | `0.5` | `vad.threshold`, 0.0-1.0; higher needs louder speech (energy: about 0.001 / 0.01 / 0.1 RMS at 0 / 0.5 / 1) |
| `marchyo.dictation.silenceGate.minSpeechMs` | `100` | `vad.min_speech_duration_ms`; recordings with less detected speech are dropped |
| `marchyo.dictation.indicator` | `true` | Top-bar recording-state segment (streams `voxtype status --follow`) |
| `marchyo.dictation.notify` | `true` | Desktop notifications on record start/stop/transcription |
| `marchyo.dictation.audioFeedback` | `true` | Start/stop sound cues |
| `marchyo.dictation.statusWindow` | `true` | Super+Shift+H floating status window + its Hyprland rule |

With `backend = "voxtype"`, `modules/home/voxtype.nix` configures the **upstream** home-manager `services.voxtype` module (config at `~/.config/voxtype/config.toml`, a `voxtype` user service). It defaults `services.voxtype.package` to `pkgs.voxtype-vulkan` (the GPU/Vulkan Whisper build) rather than the stock CPU-only `pkgs.voxtype` — the stock package is a source build with no GPU engine compiled in, so it runs `large-v3-turbo` on CPU (very slow); the Vulkan build covers NVIDIA/AMD/Intel in one binary and falls back to CPU when no device is present. `marchyo.dictation.gpu = false` forces the CPU build. Recording is driven two ways (omarchy parity): the daemon's evdev push-to-talk hotkey (hold `pushToTalk.key`, default F9) and a bind from `lib/keybinds.nix` (`toggleKey`, default `Super+Ctrl+X`) that runs `marchyo dictation toggle`; text is typed at the cursor with a clipboard fallback. The evdev hotkey needs `/dev/input` access, so `modules/nixos/dictation.nix` adds dictation users to the `input` group whenever `pushToTalk.enable` is set (a real privilege: any process the user runs can then observe keystrokes). Set `pushToTalk.enable = false` to rely only on the compositor toggle and skip the group membership. Options live in `modules/nixos/options/dictation.nix`. With `preloadModel = false`, the ~1.5 GB Whisper model downloads on first recording (a pure rebuild never blocks on the network); set it `true` to fetch it at activation via voxtype's model-loader service.

Depth options (all off by default): `onDemandModel` maps to voxtype's `whisper.on_demand_loading` (load the model on record start, unload after transcription) and `gpuIsolation` to `whisper.gpu_isolation`, together the answer to "stop the model daemon rather than leaving VRAM pinned"; `replacements` and `spokenPunctuation` map to voxtype's `[text]` block (emitted only when set). Push-to-talk (hold to record, release to transcribe) is already provided by the daemon's `pushToTalk` hotkey mode.

The silence gate (`silenceGate`, on by default) maps to voxtype's `[vad]` section. The daemon runs detection after recording stops and before transcription; a recording without enough detected speech is discarded (cancel cue, empty outcome, nothing typed), which stops Whisper hallucinating text from silence. The default `energy` backend needs no model. The `whisper` backend loads `ggml-silero-vad.bin` from voxtype's models directory, which marchyo does not fetch: when the file is missing the daemon logs a warning at startup and runs ungated.

The four UI sub-options are on by default when dictation is enabled (each opt-out) and are the "full UI" layer on top of the headless daemon. voxtype's built-in `[output.notification]`/`[audio.feedback]` drive notifications and sound (no bespoke scripts). The shell bar shows the dictation state from the `voxtype status --follow` stream (`marchyo.dictation.indicator`, baked into the shell package). The status window reuses the music-player floating pattern (`--class=org.omarchy.voxtype` matched by the `floating-window` tag rule). `voxtype.nix` sets `services.voxtype.wayland.display = "wayland-1"` so the daemon unit has `WAYLAND_DISPLAY` + `wtype`/`wl-clipboard` for `output.mode = "type"`.

## Notifications (in-shell)

The shell (on by default with the desktop) owns `org.freedesktop.Notifications` and adds a **notification history** and **per-sender rules** on top of the live toast stack. Every received notification is snapshotted into a persistent history (data snapshots, not live objects, stored under `Quickshell.statePath` and reloaded on restart), so a dismissed toast or one missed under DND is recoverable. The DND bar widget shows an unread count and opens the history centre on right-click; `Super+N` toggles the centre; `Super+Ctrl+Shift+comma` clears the live stack.

`marchyo.notifications.rules` is a list of per-sender rules matched on `appName` and/or `desktopEntry` (exact, case-insensitive; first match wins), baked into the shell at build time. Only used when the shell is on.

| Rule field | Default | Description |
|--------|---------|-------------|
| `appName` | `""` | Match the notification's application name |
| `desktopEntry` | `""` | Match the notification's desktop-entry id |
| `showToast` | `true` | Show an on-screen toast (false = history only, no popup) |
| `saveHistory` | `true` | Record in the notification-centre history |
| `bypassDnd` | `false` | Show the toast even while do-not-disturb is on |
| `overrideDuration` | `-1` | Toast timeout in ms (`-1` = sender/urgency default, `0` = never expire) |

Example:

```nix
marchyo.notifications.rules = [
  { appName = "Slack"; bypassDnd = true; }
  { desktopEntry = "org.telegram.desktop"; saveHistory = false; }
];
```

Options live in `modules/nixos/options/notifications.nix`; the apply logic is in `shell/Services/NotificationState.qml` (pure match/eviction helpers in `shell/Commons/Notify.js`, unit-tested).

## Application launcher (in-shell launcher)

`marchyo.launcher.enable` (auto-enabled with `marchyo.desktop.enable` via `lib.mkDefault`) binds the shell's own launcher (`shell/Launcher/`): `Super+R` (apps), `Super+period` (emoji picker), and `Super+Ctrl+V` (clipboard history). The binds also need `marchyo.shell.enable`; without the shell they are not bound (eval-tested in `tests/eval/marchyo-shell.nix`).

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.launcher.enable` | `true` with desktop (mkDefault) | Bind the in-shell launcher |

Options in `modules/nixos/options/launcher.nix`. `modules/nixos/options/removed.nix` declares the retired Vicinae options (`keybinding`, `inputServer`, `telemetry`, `declutter`, `settings`), so a definition fails with a pointer to the in-shell launcher.

## Web apps (PWA windows + launch binds)

`marchyo.webapps.enable` (auto-enabled with `marchyo.desktop.enable` via `lib.mkDefault`; opt out with `marchyo.webapps.enable = false`) registers a list of sites as standalone browser "app" windows. Each entry in `marchyo.webapps.apps` becomes a freedesktop `.desktop` launcher (browser `--app=<url>`, no tabs/chrome) and, when it declares a `key`, an omarchy-style Hyprland keybinding.

| Option | Default | Description |
|--------|---------|-------------|
| `marchyo.webapps.enable` | `true` with desktop (mkDefault) | Register web apps as `.desktop` entries + launch binds |
| `marchyo.webapps.browser` | `null` | Chromium-family browser for `--app` mode; `null` follows `marchyo.defaults.browser`, else chromium |
| `marchyo.webapps.apps` | (ChatGPT, GitHub, YouTube, WhatsApp, Discord, Zoom, X, Google Photos, Google Calendar, Gmail) | List of `{ name; url; icon?; key?; modifiers?; }` |

Each app's submodule: `name` (label + slugified `.desktop` id), `url`, `icon` (default generic web icon), `key` (Hyprland key, `null` = no bind), `modifiers` (default `"SUPER SHIFT"`). The default set binds ChatGPT→`A`, GitHub→`G`, YouTube→`Y`, WhatsApp→`W`, Zoom→`Z`, X→`X`, Google Photos→`P`; **Discord, Google Calendar and Gmail have no default key** (`SUPER+SHIFT+D` is the scratchpad-move bind). Other taken `SUPER+SHIFT` letters to avoid: `C` (hyprpicker), `H` (dictation status), `I` (fcitx5), `O` (OCR), `S` (satty). Options in `modules/nixos/options/webapps.nix`; implementation in `modules/home/webapps.nix`. The browser is resolved once: explicit `webapps.browser` → chromium-based `marchyo.defaults.browser` → chromium (pulled into the profile via `home.packages` when the default browser isn't chromium-family, e.g. firefox). `modules/home/webapps.nix` contributes its launch binds through `marchyo.keybinds.webapps`, reusing that resolved browser command. Note `modules/home/hyprland.nix` already carries window rules keyed on Chrome's generated app classes (e.g. `chrome-youtube.com__-Default`) for opacity/tag handling.

## Breaking Changes

### `marchyo.defaults.email = "thunderbird"` is REMOVED

`thunderbird` is no longer a valid `marchyo.defaults.email` value (the enum will
reject it at evaluation). Switch to the TUI client (`"aerc"`) or a web
client (`"gmail"`, `"outlook"`). There is no in-place migration — Thunderbird's
native GUI is no longer managed by marchyo.

### Retired features

`modules/nixos/options/removed.nix` declares each retired option, so a
definition fails with a pointer to its replacement.

- Vicinae (`marchyo.launcher.{keybinding,inputServer,telemetry,declutter,settings}`)
  and noctalia: the in-shell launcher of `marchyo.shell` covers the launcher;
  `marchyo.launcher.enable` stays and gates its binds.
- waybar, mako and SwayOSD (`marchyo.osd.enable`): the shell draws the bar,
  the notifications and the OSD. With `marchyo.shell.enable = false` there is
  no bar, notification daemon or OSD; the media keys run plain
  `wpctl`/`brightnessctl` (`modules/nixos/backlight.nix` keeps the backlight
  writable).
- `marchyo.gaming`, `marchyo.console.kmscon`,
  `marchyo.snapshots` (snapper): configure `programs.steam`, `services.kmscon`
  or `services.snapper` on the host directly.
- The `marchyo.defaults` values `audioPlayer = "cmus"`, `musicPlayer =
  "ncspot"` and `email = "neomutt"`: the enums reject them; enable
  `programs.cmus`, `programs.ncspot` or `programs.neomutt` in Home Manager.

### Deprecated Options

- `marchyo.keyboard.variant` → use `{ layout = "us"; variant = "intl"; }` in layouts
