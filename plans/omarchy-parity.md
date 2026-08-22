# Omarchy → Marchyo: gap analysis + implementation plan

This document has two parts:
- **Part A — Gap analysis:** a full comparison of [basecamp/omarchy](https://github.com/basecamp/omarchy) against marchyo (what's missing, what differs, what's out of scope).
- **Part B — Implementation plan:** the subset selected for porting, with concrete file-level steps.

---

# PART A — Gap analysis

## Context

Marchyo is a NixOS re-implementation of the ideas in omarchy (DHH/Basecamp's opinionated Arch + Hyprland distro). This part is a **comparison inventory**: what omarchy ships that marchyo does not, and where the two implement the same idea differently.

Both inventories were taken from **current sources**: omarchy `master` (mid-2026) read directly from the repo, and marchyo from the working checkout (includes the in-progress dictation work).

A structural fact that reframes half of omarchy's surface: **omarchy is an imperative Arch overlay** — a huge `bin/omarchy-*` script library that mutates a running system (install/remove/update/refresh/migrate). **Marchyo is declarative NixOS** — that entire category is replaced by `nixos-rebuild` + flake inputs and is *not* a gap (see §A5).

## A1. Deliberate divergences (NOT gaps)

- **Flat TUI aesthetic.** Marchyo forces `rounding=0`, `gaps=0`, `border=2`, `animations=off`, no blur/shadow. Omarchy ships those and exposes runtime toggles (`SUPER+Backspace` transparency, `SUPER SHIFT+Backspace` gaps, `SUPER CTRL+Backspace` single-window aspect). Marchyo intentionally omits those toggles.
- **App-launch keybind namespace.** Omarchy launches apps on `SUPER+SHIFT+<letter>`; marchyo on plain `SUPER+<letter>`. The whole map is shifted — not "missing".
- **`SUPER+S` / `SUPER+D`.** Marchyo (recent commit): `SUPER+S` = screenshot area, `SUPER+D` = scratchpad "Drawer". Omarchy: `SUPER+S` = scratchpad, `SUPER SHIFT+D` = lazydocker, `PRINT` = screenshot.
- **Launcher.** Omarchy = Walker + Elephant (`SUPER+SPACE`). Marchyo = Vicinae (`SUPER+R`).
- **Single theme, declarative switch.** Marchyo = one Jylhis theme, `dark`/`light` via `marchyo.theme.variant`. Omarchy = 19 themes + runtime picker.
- **noctalia present but disabled** on purpose (would seize the notification bus).

## A2. Features MISSING from marchyo (impact-ordered)

1. **Central system menu** — omarchy's `omarchy-menu` (`SUPER ALT+SPACE`): Apps · Learn · Trigger · Style · Setup · Install · Remove · Update · About · System. Marchyo has no aggregator. Even excluding the declarative-N/A branches, Trigger/Style/Setup/System/Learn have real value and no counterpart.
2. **Power/session menu** — omarchy `omarchy-system-{lock,logout,reboot,shutdown,suspend}`. Marchyo has only `SUPER+L` (hyprlock) and `CTRL ALT+Delete` (hard poweroff). No logout/reboot/suspend/hibernate affordance.
3. **On-screen display (SwayOSD)** — omarchy routes volume/brightness/mic/kbd-backlight through SwayOSD. Marchyo changes them silently.
4. **Screensaver** — omarchy `tte` (terminaltexteffects) screensaver, idle-launched, brandable. Marchyo: none.
5. **Runtime theme + background switcher** — omarchy: 19 themes, `omarchy-theme-*`, background/theme pickers, per-key keyboard RGB. Marchyo: single theme, NixOS-option variant, single generated wallpaper, no runtime switcher/cycler, no keyboard RGB.
6. **Productivity "Trigger" utilities** — reminders (`SUPER CTRL+R`…), weather (waybar + `SUPER CTRL ALT+W`), quick-info notify (`SUPER CTRL ALT+T`/`B`), transcode (`SUPER CTRL+.`), share menu (`SUPER CTRL+S`). None in marchyo.
7. **Notification silencing / DND** — omarchy `SUPER CTRL+,` toggle + indicator, invoke/restore-last. Marchyo has dismiss-last/all only, no DND, no indicator.
8. **Universal clipboard copy/paste/cut** — omarchy `SUPER+C/V/X` work in terminals too (`sendshortcut`). Marchyo: none (only cliphist watchers + Vicinae history).
9. **Connectivity control menus** — omarchy `SUPER CTRL+A/B/W` → audio/bluetooth/wifi menus. Marchyo approximates via waybar clicks to TUIs (present-but-different, bar-only).
10. **Web-app (PWA) system** — omarchy: `omarchy-webapp-install/-remove`, custom icons, HEY/Zoom handlers, dedicated binds (`SUPER SHIFT+A` ChatGPT, `+C` HEY Calendar, `+E` HEY Email, `+Y` YouTube, `SUPER SHIFT ALT+G` WhatsApp, `+P` Photos, `+X` X). Marchyo's `webapps.nix` is off by default, fewer apps, no icons, no binds.
11. **Display/monitor runtime controls** — monitor scaling cycle (`SUPER+/`), toggle laptop display/mirror (`SUPER CTRL+Delete`/`+ALT+Delete`), lid-switch auto-management. Marchyo: hyprmon TUI + kanshi, no hotkeys.
12. **Misc launches** — tmux "Work" session (`SUPER ALT+RETURN`), nautilus-at-cwd (`SUPER ALT SHIFT+F`), docker TUI (lazydocker, `SUPER SHIFT+D`), font picker. Marchyo: none of these binds (fonts fixed via Stylix).
13. **System-integration extras** — first-run onboarding + About dialog, hooks system (`battery-low`/`theme-set`/`post-boot` drop-ins), hardware quirk scripts (`omarchy-hw-*`; marchyo delegates to `nixos-hardware`), gaming install helpers.

## A3. Present-but-DIFFERENT

| Capability | Omarchy | Marchyo |
|---|---|---|
| Launcher | Walker + Elephant, `SUPER+SPACE` | Vicinae, `SUPER+R` |
| Emoji picker | Walker symbols, `SUPER CTRL+E` | Vicinae, `SUPER+period` |
| Clipboard history | Walker, `SUPER CTRL+V` | Vicinae, `SUPER CTRL+V` (same combo) |
| Paste-at-cursor | Walker types the selection | Vicinae types it too, via the `cap_dac_override` input-server wrapper (`marchyo.launcher.inputServer.enable`); set false and both fall back to clipboard-only |
| Color picker | hyprpicker, `SUPER+PRINT` | hyprpicker, `SUPER SHIFT+C` |
| Screen recording | menu, `ALT+PRINT` | `marchyo-screenrecord-toggle`, `SUPER ALT+PRINT` |
| Screenshot | `PRINT` | `PRINT` / `SUPER+S` (grimblast + satty) |
| Connectivity | dedicated menus (`SUPER CTRL+A/B/W`) | waybar clicks → TUIs |
| Theme switch | runtime picker, 19 themes | `marchyo.theme.variant` option, 1 theme |
| Wallpaper | swaybg + picker/cycler | awww daemon, single theme-tied image |
| Update surface | `omarchy-update` menu + waybar indicator | `nixos-rebuild` + `dix` diff, `marchyo` CLI |
| Login / Boot | SDDM / Limine | greetd + tuigreet / systemd-boot |

**Already at parity** (same tool/behavior): mako, voxtype dictation (incl. F9 PTT + `SUPER CTRL+X`), hyprsunset nightlight (`SUPER CTRL+N`), idle-lock toggle (`SUPER CTRL+I`), cursor zoom (`SUPER CTRL+Z`), toggle top bar (`SUPER SHIFT+SPACE`), keybindings cheatsheet (`SUPER+K`), OCR, notification dismiss (`SUPER+,`), window grouping/tiling, hyprlock, hypridle.

## A4. Where marchyo goes BEYOND omarchy

- **BYOK AI desktop** — OpenRouter routing buckets, pi/claude-code, OpenViking context, MCP (mcp-nixos), Agent Skills.
- **Reproducibility & multi-platform** — one flake builds NixOS + nix-darwin + nix-on-droid; declarative rollback; disko/installer ISOs.
- **Editor integration** — jotain (Jylhis Emacs) as first-class default with daemon + Hyprland wiring.
- **Performance module** — declarative kernel/sysctl/IO tuning.

## A5. Omarchy surface that is N/A under NixOS

Not gaps — replaced by the declarative model: `omarchy-install-*`, `-remove-*`, `-pkg-*`, `-update-*`, `-migrate`, `-reinstall`, `-refresh-*` (config regen), channel switching (Stable/RC/Edge/Dev), firmware menu, `-sudo-passwordless`. All map to editing Nix modules + `nixos-rebuild`. Marchyo's `marchyo`/`marchyoctl` CLI + `dix` diff cover the "what changed / rebuild" slice.

---

# PART B — Implementation status

**All selected Part B scope shipped 2026-07-18** (batch PRs #107–#120).
**Weather** and the **runtime font picker** were explicitly dropped from scope.

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

## Remaining follow-ups

- **Share upload target** — `marchyo-share` stages clipboard/file/folder paths;
  an actual upload backend was deferred (decision pending).
- **hyprlock live theme swap** — rebuild-only for now; a `source =` include
  would make it runtime-swappable (#118 follow-up).
- **Multi-theme** — the dark↔light toggle's store-dir + pointer layout is
  forward-compatible with N base16 variants (plan.md F3.3).
- **CLI wrappers** — the `marchyo-*` scripts are keybind/menu-driven; plan.md
  F3.2 wraps them in `marchyo` CLI subcommands.
- **Docs sync** — the new binds and options need `docs/usage/hotkeys.mdx` +
  `docs/configuration/` entries (tracked in the batch-coordinator PR).
