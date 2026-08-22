# Omarchy → Marchyo: gap analysis + implementation status

This document has three parts:
- **Part A — Gap analysis:** a full comparison of [basecamp/omarchy](https://github.com/basecamp/omarchy) against marchyo (what's missing, what differs, what's out of scope). Refreshed against omarchy **4.0.0.alpha**.
- **Part B — Implementation status (2026-07 batch):** the pre-4.0 subset selected for porting, shipped in PRs #107–#120. Kept as historical record.
- **Part C — Quickshell-era follow-up:** the new gap opened by omarchy 4.0's unified shell, tracked in [`shell.md`](shell.md).

---

# PART A — Gap analysis

## Context

Marchyo is a NixOS re-implementation of the ideas in omarchy (DHH/Basecamp's opinionated Arch + Hyprland distro). This part is a **comparison inventory**: what omarchy ships that marchyo does not, and where the two implement the same idea differently.

Both inventories were taken from **current sources**: omarchy read directly from the repo at **version `4.0.0.alpha`** (`omarchy/version`), and marchyo from the working checkout.

**The single biggest change since the last revision of this doc:** omarchy has collapsed its desktop shell into **one long-running Quickshell (QML) process, `omarchy-shell`** (`omarchy/shell/shell.qml`), with a **manifest.json-based plugin system**. The bar, notifications, OSD, lock screen, menus, panels, app launcher, clipboard and emoji pickers, polkit agent, and background/theme pickers are now **plugins inside that one process**, not separate daemons. This retires the tools the previous gap analysis compared against: **Walker + Elephant** (launcher), **mako/dunst** (notifications), **SwayOSD** (OSD), **hyprlock** (as a standalone), and the discrete waybar. Omarchy *unified*; **marchyo still composes discrete, best-of-breed tools** (`waybar.nix`, `mako.nix`, `vicinae.nix`, `swayosd.nix`, `screensaver.nix`, `menus.nix`, `hyprland.nix`). Marchyo ships its own Quickshell shell module (`modules/home/noctalia.nix`) but keeps it **disabled** (`programs.noctalia.enable = lib.mkDefault false`) so it does not seize the notification bus. That architectural fork reframes half of the comparison below (§A3 especially), and is the subject of [`shell.md`](shell.md).

A second structural fact still holds: **omarchy is an imperative Arch overlay** — a huge `bin/omarchy-*` script library (now **431** scripts) that mutates a running system, and which is also the glue that drives the new shell over IPC. **Marchyo is declarative NixOS** — that install/remove/update/migrate category is replaced by `nixos-rebuild` + flake inputs and is *not* a gap (see §A5).

### How the omarchy shell is organized (source: `omarchy/shell/`, `omarchy/docs/omarchy-shell.md`)

- **Host:** `shell.qml` boots a `ShellRoot`, injects shared singletons (`PluginRegistry`, `BarWidgetRegistry`, `AppLibrary` in `shell/services/`), reads defaults from `config/omarchy/shell.json` and user overrides from `~/.config/omarchy/shell.json` (**no deep-merge — user file is canonical once it exists**).
- **Plugin kinds** (`docs/omarchy-shell.md`): `bar-widget`, `bar` (full-bar replacement), `panel` (floating window), `overlay` (fullscreen), `menu` (summoned surface), `service` (headless singleton). A manifest may declare several kinds.
- **First-party plugins** (`shell/plugins/`):
  - **bar** (`plugins/bar/`) — widgets `Workspaces`, `Clock`, `ActiveWindow`, `Tray`, `Microphone`, `KeyboardLayout`, `SystemUpdate`, `Spacer`, and an `Indicators` cluster (`indicators/`: `Dictation`, `Dnd`, `NightLight`, `Reminder`, `ScreenRecording`, `StayAwake`).
  - **panels** (`plugins/panels/`) — `audio`, `bluetooth`, `clock`, `monitor`, `network`, `power`, `weather`, `tailscale`, `dropbox`, `speedtest`, `disk-speedtest`, `wifiqr`.
  - **services** (`plugins/services/`) — `battery`, `idle`, `media`, `nightlight`.
  - **surfaces** — `menu`, `notifications`, `osd`, `lock`, `polkit`, `background`, `image-picker`, `emojis`, `clipboard`, `reminders`, `agents` (AI agents), `dev-gallery`.
- **IPC contract** (the canonical CLI→shell path via `omarchy-shell`): `summon <id>`, `hide <id>`, `toggle <id>`, `togglePanelAt <section> <index>`, `call`, `rescanPlugins`, `reloadConfig`, `applyTheme`, `setPluginEnabled`, `listPlugins`, etc. Third-party plugins are git repos cloned into `~/.config/omarchy/plugins/<id>/`, managed by `omarchy plugin add|update|remove|enable|disable`.
- **Theme tokens** flow to QML via three `qs.Commons` singletons — `Color`, `Style`, `Border` — sourced from `themes/<name>/colors.toml` + a generated/overridable `shell.toml` (surface roles, `[controls]`, `[spacing]`, `[font]`, `[bar]` sizing).

## A1. Deliberate divergences (NOT gaps)

- **Discrete composition vs. unified shell.** *This is now the headline divergence.* Omarchy runs one Quickshell process hosting bar/notifications/OSD/lock/launcher/menus as plugins. Marchyo deliberately composes discrete tools (waybar + mako + swayosd + vicinae + hyprlock + custom menu scripts). Marchyo's own Quickshell shell (`noctalia.nix`) exists but is intentionally off. This is a design choice, not a missing feature — but it is what makes the tool-by-tool comparison in §A3 look the way it does. Whether to close it is the subject of [`shell.md`](shell.md).
- **Flat TUI aesthetic.** Marchyo forces `rounding=0`, `gaps=0`, `border=2`, `animations=off`, no blur/shadow. Omarchy ships those and exposes runtime toggles (`SUPER+Backspace` window transparency, `SUPER SHIFT+Backspace` gaps, `SUPER CTRL+Backspace` single-window square aspect — see `default/hypr/bindings/utilities.lua`). Marchyo intentionally omits those toggles.
- **App-launch keybind namespace.** Omarchy launches apps on `SUPER+SHIFT+<letter>` (`default/hypr/bindings/applications.lua`); marchyo on plain `SUPER+<letter>`. The whole map is shifted — not "missing".
- **Launcher engine.** Omarchy **no longer uses Walker + Elephant.** `SUPER+SPACE` now toggles the Quickshell **menu plugin** root (`omarchy-menu toggle`), and `SUPER+ALT+SPACE` opens the app launcher, which is the menu's `apps` provider drawing from the shared `AppLibrary` (`shell/plugins/menu/`, `shell/services/AppLibrary.qml`). Marchyo uses **Vicinae** (`vicinae.nix`, `SUPER+R`). Different engines, deliberate.
- **Single theme, declarative switch.** Marchyo = one Jylhis theme, `dark`/`light` via `marchyo.theme.variant`. Omarchy = **22 themes** + runtime picker (was 19).
- **`marchyo` CLI vs. `omarchy` CLI.** Both wrap their system; marchyo's is declarative-first.

## A2. Features MISSING from marchyo (impact-ordered)

1. **Central command menu as a live QML surface.** Omarchy's `omarchy.menu` plugin (`SUPER+SPACE` root; `SUPER+ESCAPE` system; sub-routes `apps`, `capture`, `toggle`, `hardware`, `background`, `theme`, `share`, `reminder-set`) is a data-driven menu defined in `default/omarchy/omarchy-menu.jsonc`, hot-reloaded, with bash `when/checked/disabled` guards, `provider:` rows (apps, fonts, power-profiles), and a `select`/`input` dmenu mode (`omarchy-menu-select`/`-input`). Marchyo shipped `marchyo-menu`/`marchyo-power-menu` (`menus.nix`, prior Part B) as **static wofi/fuzzel-style scripts** — functional, but not a searchable, guarded, provider-backed, hot-reloaded surface. Gap is now *architectural*, not just feature-coverage.
2. **Notifications as a first-class, persistent, restart-surviving server.** Omarchy's `notifications` plugin *is* the freedesktop daemon (`shell/plugins/notifications/Service.qml`), with per-toast JSON persistence under `~/.local/state/omarchy/notifications/`, a 10-item history replay, `replaces_id` in-place rewrite, DND punch-through rules, and a single sender contract (`omarchy-notification-send`, never raw `notify-send`). Marchyo uses **mako** (`mako.nix`) — solid, but no history replay, no persistence across restart, no structured sender contract. (DND toggle + indicator *was* added to marchyo; see §A3.)
3. **Lock screen as a themed shell plugin.** Omarchy's `lock` plugin (`shell/plugins/lock/`) renders inside the shell with per-theme `shell.lock.toml` + `unlock.png`/`preview-unlock.png` assets. Marchyo uses **hyprlock** (`screensaver.nix`/hyprland wiring) with rebuild-time theming only.
4. **Bar panels / connectivity as rich QML panels.** Omarchy exposes 12 floating panels (`audio`, `bluetooth`, `network`, `monitor`, `power`, `clock/calendar`, `weather`, `tailscale`, `dropbox`, `speedtest`, `disk-speedtest`, `wifiqr`) toggled by `SUPER+CTRL+<letter>` and by `togglePanelAt` (numeric `SUPER+CTRL+1..9`). Marchyo approximates a few via waybar clicks to TUIs; it has **no tailscale/dropbox/speedtest/wifi-QR panels**.
5. **AI "agents" desktop surface.** Omarchy ships an `agents` plugin (`shell/plugins/agents/`, `SUPER SHIFT CTRL+A` → `omarchy-agent --pick`) plus a crash-capture agent (`omarchy-crash-watch` → `omarchy-agent-crash`). Marchyo has BYOK AI (see §A4) but no equivalent in-shell agent picker/overlay.
6. **Runtime theme + background switcher across 22 themes.** Omarchy: `SUPER+CTRL+SPACE` background switcher, `SUPER SHIFT+CTRL+SPACE` theme menu, per-theme `keyboard.rgb`, `backgrounds/`, previews. Marchyo: single theme, `marchyo.theme.variant` option, ephemeral light/dark runtime toggle (`theme-runtime.nix`), no multi-theme cycler, no per-key keyboard RGB.
7. **Screensaver + idle as shell services with unified config.** Omarchy folds `idle.screensaver`/`idle.lock` (seconds) into `shell.json` and runs them as the `idle` service plugin. Marchyo has a discrete tte screensaver (`screensaver.nix`) + hypridle; parity on behavior, but not unified config.
8. **Live theme apply without rebuild.** Omarchy pushes theme changes into the running shell via `applyTheme <colorsB64> <shellB64>` IPC. Marchyo's theming is rebuild-time (plus the ephemeral light/dark overlay).
9. **Calculator, OCR-on-capture, webcam overlay, transcode, share** — omarchy `omacalc` (`SUPER+CTRL+Q`), `omarchy-capture-text` OCR (`SUPER+CTRL+PRINT`), webcam overlay resize (`SUPER+ALT+minus/equal`), `omarchy-transcode` (`SUPER+CTRL+PERIOD`), share menu (`SUPER+CTRL+S`). Marchyo added transcode/share/reminders utilities previously; **no calculator, no webcam overlay**.
10. **Plugin ecosystem** — omarchy's git-repo plugin model (`omarchy plugin add/update/remove/enable`) has no marchyo analog; under NixOS this would be a flake-input/module story (see §A5), but the *third-party live-extension* affordance is genuinely absent.
11. **System-integration extras** — first-run onboarding, hooks (`battery-low`/`theme-set`/`post-boot`), `omarchy-migrate-notify`, crash capture, gaming/hardware helpers.

## A3. Present-but-DIFFERENT

The whole left column has shifted from "discrete daemon" to "plugin inside `omarchy-shell`". That is the story of this table.

| Capability | Omarchy 4.0.0.alpha | Marchyo |
|---|---|---|
| Bar | `omarchy.bar` **Quickshell plugin** (widgets + indicators), config in `shell.json` | **waybar** (`waybar.nix`), discrete |
| Notifications | `notifications` **shell plugin** = the fdo daemon, persistent history, sender contract | **mako** (`mako.nix`); DND toggle + waybar indicator added (`SUPER CTRL+,`) |
| OSD (vol/brightness) | `osd` **shell plugin** (panel kind), fed by `omarchy-audio-*`/`omarchy-brightness-*` | **SwayOSD** (`swayosd.nix` + `modules/nixos/osd.nix`) |
| Lock screen | `lock` **shell plugin**, per-theme `shell.lock.toml` | **hyprlock** (`SUPER+CTRL+L` / `SUPER+L`) |
| App launcher | menu plugin `apps` provider / `AppLibrary` (`SUPER+SPACE` root, `SUPER+ALT+SPACE` apps) — **Walker/Elephant retired** | **Vicinae** (`vicinae.nix`, `SUPER+R`) |
| Emoji picker | `emojis` shell plugin (`SUPER+CTRL+E`) | Vicinae (`SUPER+period`) |
| Clipboard history | `clipboard` shell plugin (`SUPER+CTRL+V`) | Vicinae + cliphist (`SUPER+CTRL+V`) |
| Universal copy/paste/cut | `SUPER+C/V/X`, **terminal-aware** (CTRL vs. CTRL/SHIFT+Insert) via Hyprland send-key (`bindings/clipboard.lua`) | `SUPER+C/V/X` (sends CTRL+Insert / SHIFT+Insert / CTRL+X) |
| Command/system menu | `omarchy.menu` JSONC-defined, hot-reloaded, guarded, provider-backed | `marchyo-menu`/`marchyo-power-menu` static scripts (`menus.nix`) |
| Connectivity | rich QML panels `SUPER+CTRL+A/B/W/D` + numeric `togglePanelAt` | waybar clicks → TUIs |
| Media keys | `omarchy-shell media next/playPause/previous` (shell `media` service) | mpris/playerctl |
| Theme switch | runtime picker, **22 themes**, live `applyTheme` IPC | `marchyo.theme.variant` + ephemeral light/dark toggle, 1 theme |
| Wallpaper | `background` shell plugin + switcher | awww daemon, single theme-tied image |
| Reminders | `reminders` shell overlay + `omarchy-reminder` (systemd transient timers) + bar indicator | `marchyo-*` reminders (`utilities.nix`), notify-driven |
| Nightlight | `nightlight` shell service (`SUPER+CTRL+N`) | hyprsunset (`SUPER+CTRL+N`) |
| Polkit agent | `polkit` shell plugin | discrete polkit agent |
| Screenshot | `PRINT` → `omarchy-capture-screenshot`, keyboard-driven region picker | `PRINT` / `SUPER+S` (grimblast + satty) |
| Screen recording | `ALT+PRINT` → `omarchy-capture-screenrecording` | `marchyo-screenrecord-toggle` |
| Color picker | hyprpicker (`SUPER+PRINT`) | hyprpicker (`SUPER SHIFT+C`) |
| Update surface | `omarchy-update` + `SystemUpdate` bar widget | `nixos-rebuild` + `dix` diff, `marchyo` CLI |
| Login / Boot | SDDM / Limine | greetd + tuigreet / systemd-boot |

**Still at parity** (same behavior, even if omarchy's side moved into the shell): voxtype dictation (+ bar `Dictation` indicator), idle-lock toggle (`SUPER+CTRL+I`), nightlight toggle, cursor zoom (`SUPER+CTRL+Z`), toggle top bar (`SUPER SHIFT+SPACE`), keybindings cheatsheet (`SUPER+K`), notification dismiss (`SUPER+,`), window grouping/tiling, monitor internal-display toggle (`SUPER+CTRL+Delete`).

## A4. Where marchyo goes BEYOND omarchy

- **BYOK AI desktop** — OpenRouter routing buckets, pi/claude-code, OpenViking context, MCP (mcp-nixos), Agent Skills. (Omarchy 4.0 added an in-shell `agents` plugin, so this is narrowing, but marchyo's provider-agnostic BYOK routing is broader.)
- **Reproducibility & multi-platform** — one flake builds NixOS + nix-darwin + nix-on-droid; declarative rollback; disko/installer ISOs. Omarchy remains Arch-only and imperative.
- **Declarative, atomic system state** — the entire `omarchy-*` install/remove/update/migrate surface (431 scripts) is replaced by `nixos-rebuild` + flake pins with rollback.
- **Editor integration** — jotain (Jylhis Emacs) as first-class default with daemon + Hyprland wiring.
- **Performance module** — declarative kernel/sysctl/IO tuning.

## A5. Omarchy surface that is N/A under NixOS

Not gaps — replaced by the declarative model:

- **Imperative package/system mutation** — `omarchy-install-*`, `-remove-*`, `-pkg-*`, `-update-*`, `-migrate`, `-reinstall`, `-refresh-*` (the `refresh-` copy-default-config-to-`~/.config` mechanism), channel switching, firmware menu, `-sudo-passwordless`. All map to editing Nix modules + `nixos-rebuild`.
- **The git-repo plugin manager** (`omarchy plugin add/update/remove`) — the *live third-party extension* model is intentionally imperative; the NixOS equivalent is a flake input + Home-Manager module, evaluated at build time. (The affordance itself is noted as absent in §A2.10; the *imperative implementation* is N/A.)
- **`refresh-*` config regeneration** and the three-tree doc split omarchy uses (`config/` runtime configs, `default/` templates incl. `default/themed/*.tpl`, `manual/`+`docs/`+`agents/skills/`) — marchyo generates all of `~/.config` from Nix, so there is no copy-and-refresh step to mirror. (Marchyo has since adopted the same *documentation* three-tree split: [`docs/`](../docs/), [`manual/`](../manual/), and this `plans/` tree.)

Omarchy's own forward-looking RFCs live in `omarchy/plans/` (`backup.md` — off-site encrypted restic backup with a bar panel; `dots.md` — user-config preservation/sync; `server.md` — a headless "BBS" edition). Under NixOS, backup/dots are already covered declaratively; the server edition is out of scope.

---

# PART B — Implementation status (2026-07 batch)

**All selected pre-4.0 Part B scope shipped 2026-07-18** (batch PRs #107–#120).
**Weather** and the **runtime font picker** were explicitly dropped from scope.
This section is kept as historical record; several of these features now have a
*different* omarchy counterpart because omarchy moved them into its Quickshell
shell (see Part A / Part C).

| Feature | Where it lives | PR |
|---|---|---|
| Power/session menu (`SUPER, Escape`) | `modules/home/menus.nix` → `marchyo-power-menu` | [#113](https://github.com/Jylhis/marchyo/pull/113) |
| Central system menu (`SUPER ALT, Space`) | `modules/home/menus.nix` → `marchyo-menu`; `marchyo.menus.enable` | [#113](https://github.com/Jylhis/marchyo/pull/113) |
| SwayOSD volume/brightness overlay | `modules/home/swayosd.nix` + `modules/nixos/osd.nix` (udev + video group); `marchyo.osd.enable` | [#107](https://github.com/Jylhis/marchyo/pull/107) |
| DND toggle + waybar indicator (`SUPER CTRL, comma`; dismiss-all moved to `SUPER CTRL SHIFT, comma`) | `modules/home/{mako,window-toggles,waybar}.nix` → `marchyo-dnd-toggle` | [#110](https://github.com/Jylhis/marchyo/pull/110) |
| Universal clipboard `SUPER+C/V/X` (sends CTRL+Insert / SHIFT+Insert / CTRL+X; toggle-floating remapped `SUPER,V` → `SUPER,T`) | `modules/home/hyprland.nix` | [#111](https://github.com/Jylhis/marchyo/pull/111) |
| Monitor controls (`SUPER, backslash` scale cycle; `SUPER CTRL, Delete` laptop display), connectivity TUIs (`SUPER CTRL, A/B/W`), app launches (`SUPER ALT, Return` tmux Work; `SUPER ALT, D` lazydocker; `SUPER ALT SHIFT, F` file manager at cwd) | `modules/home/omarchy-binds.nix` | [#120](https://github.com/Jylhis/marchyo/pull/120) |
| Reminders (`SUPER CTRL[+ALT/+SHIFT], R`), quick-info notify (`SUPER CTRL ALT, T/B`), transcode (`SUPER CTRL, period`), share (menu-only) | `modules/home/utilities.nix`; `marchyo.{reminders,utilities}.enable` | [#115](https://github.com/Jylhis/marchyo/pull/115) |
| Web-app parity (default-on with desktop; + X, Google Photos, Google Calendar, Gmail; HEY → Google equivalents) | `modules/{nixos/options,home}/webapps.nix`, `desktop-config.nix` | [#116](https://github.com/Jylhis/marchyo/pull/116) |
| Screensaver (tte on 120s idle, keypress/mouse dismiss) | `modules/home/screensaver.nix`; `marchyo.screensaver.enable` | [#119](https://github.com/Jylhis/marchyo/pull/119) |
| Runtime light/dark switch (no rebuild; ephemeral overlay, resets on activation) | `modules/home/theme-runtime.nix` → `marchyo-theme-toggle` | [#118](https://github.com/Jylhis/marchyo/pull/118) |

## Remaining follow-ups (pre-4.0)

- **Share upload target** — `marchyo-share` stages clipboard/file/folder paths;
  an actual upload backend was deferred (decision pending).
- **hyprlock live theme swap** — rebuild-only for now; a `source =` include
  would make it runtime-swappable (#118 follow-up).
- **Multi-theme** — the dark↔light toggle's store-dir + pointer layout is
  forward-compatible with N base16 variants.
- **Docs sync** — the binds and options are documented in the site's
  `usage/hotkeys` + `configuration/` pages.

---

# PART C — Quickshell-era follow-up

Omarchy 4.0's move to a unified Quickshell shell opens a new, *architectural* gap
that the 2026-07 batch (Part B) did not — and could not — address: marchyo's
bar/OSD/notifications/lock/menu are discrete tools, while omarchy's are plugins in
one process sharing a design runtime, state, and IPC bus.

The response is **not** to chase each plugin individually, but to decide marchyo's
own shell strategy. That design lives in **[`shell.md`](shell.md)** — an RFC to
build a marchyo-native Quickshell shell (borrowing omarchy's plugin architecture,
packaged in Nix, themed from the Jylhis design system), phased so nothing in the
discrete stack is removed until the shell reaches parity for that surface. Marchyo
already ships the raw material: `modules/home/noctalia.nix` is a Quickshell shell,
currently `enable = lib.mkDefault false`.

The §A2 items that a marchyo shell would close, in priority order: the live command
menu (§A2.1), a persistent notification server (§A2.2), a themed lock surface
(§A2.3), rich connectivity panels (§A2.4), and live theme apply (§A2.8). Items that
stay out of scope under NixOS regardless of the shell: the imperative git-repo
plugin manager (§A5).
