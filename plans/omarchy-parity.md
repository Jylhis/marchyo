# Omarchy → Marchyo: gap analysis + status

Comparison of [basecamp/omarchy](https://github.com/basecamp/omarchy)
(**4.0.0.alpha**) against marchyo. This document tracks what is still
genuinely open. The shell's design record is [`shell.md`](shell.md); its
research backlog is [`shell-research.md`](shell-research.md).

## Context

Marchyo is a NixOS re-implementation of the ideas in omarchy (DHH/Basecamp's
opinionated Arch + Hyprland distro).

**Omarchy** is one long-running Quickshell (QML) process
(`omarchy-shell`) hosting bar, notifications, OSD, lock, menus, panels,
launcher, clipboard and emoji pickers, polkit agent, background/theme pickers
as **manifest.json plugins** over an IPC bus, driven by a 431-script imperative
`bin/omarchy-*` Arch overlay.

**Marchyo** composes its own Quickshell shell (`shell/`, default off,
see [`shell.md`](shell.md)) — a simple monolith with no plugin machinery —
with Vicinae/hyprlock as the shell-off fallback, and the `marchyo` CLI as the
command surface. Everything else is declarative NixOS: the whole
install/remove/update/migrate category is replaced by `nixos-rebuild` +
flake pins with rollback (see "N/A under NixOS" below).

## A1. Deliberate divergences (NOT gaps)

- **No third-party plugin system.** marchyo rejected omarchy's
  git-repo-into-`~/.config` plugin model; the shell is plain in-process QML
  and all extension is Nix-declared. The imperative `omarchy plugin
  add/update/remove` surface is intentionally absent.
- **App-launch keybind namespace.** omarchy launches on `SUPER+SHIFT+<letter>`;
  marchyo on plain `SUPER+<letter>`. The whole map is shifted, not missing.
- **CLI shape.** omarchy's CLI drives a live Arch system; marchyo's is
  runtime-first over a declarative base (runtime / `--apply` / `--revert`),
  with the flake as the source of truth.

## A2. Still MISSING from marchyo (impact-ordered)

1. **Central command menu as a live QML surface.** omarchy's menu plugin is a
   data-driven, hot-reloaded JSONC menu with bash `when/checked/disabled`
   guards, `provider:` rows, and a dmenu `select`/`input` mode. Marchyo's
   `marchyo menu` is a gum TUI (functional, themed, guarded — but not a
   searchable QML surface). Gap is architectural; whether to close it depends
   on the shell menu decision (the menu currently calls the `marchyo` CLI,
   including theme selection).
2. **System-integration extras** — first-run onboarding, lifecycle hooks
   (`battery-low`, `theme-set`, `post-boot`), crash capture, gaming/hardware
   helpers. None ported; each would need a declarative (module/timer) shape
   first. Low priority unless a concrete need appears.
3. **Per-theme keyboard RGB / backgrounds per theme.** omarchy ships
   per-theme `keyboard.rgb` and `backgrounds/`; marchyo has one
   theme-tied wallpaper per theme plus `marchyo bg set`. Niche.
4. **Extra connectivity panels.** The shell ships audio/network/power/monitor
   panels; tailscale/dropbox/speedtest/wifi-qr panels are still absent.

## A3. Present-but-DIFFERENT (kept for orientation)

| Capability | Omarchy 4.0.0.alpha | Marchyo |
|---|---|---|
| Bar | `omarchy.bar` plugin | marchyo shell `Bar/` (default off; waybar otherwise) |
| Notifications | plugin, persistent history | marchyo shell `Notifications/` (history + centre + per-sender rules); mako when shell off |
| OSD | plugin, fed by `omarchy-*` poke | marchyo shell `Osd/` (IPC poke + sysfs fallback); SwayOSD when shell off |
| Lock screen | `lock` plugin | marchyo shell `Lock/` `WlSessionLock` (`SUPER+L`); hyprlock when shell off |
| App launcher | menu plugin `apps` provider | marchyo shell `Launcher/` (`SUPER+R`); Vicinae when shell off |
| Emoji picker / clipboard | shell plugins | marchyo shell launcher (`SUPER+period` / `SUPER+Ctrl+V`); Vicinae + cliphist when shell off |
| Command/system menu | JSONC QML menu | `marchyo menu` / `marchyo-power-menu` gum TUIs |
| Media keys | shell `media` service | marchyo shell `Bar/MediaWidget` (MPRIS); mpris/playerctl otherwise |
| Theme switch | runtime picker, 22 themes, live `applyTheme` | `marchyo.theme.{variant,scheme,themes}` + runtime overlay, live-recolors the shell |
| Wallpaper | `background` plugin + switcher | awww daemon + `marchyo bg set` |
| Nightlight | `nightlight` service | hyprsunset |
| Polkit agent | `polkit` plugin | discrete polkit agent |
| Screenshot / recording | `omarchy-capture-*` | `marchyo capture` (grimblast+satty, freeze-frame OCR) / gpu-screen-recorder |
| Update surface | `omarchy-update` + widget | `nixos-rebuild` + `dix`, `marchyo update/upgrade/rollback/gc/diff` |
| Login / Boot | SDDM / Limine | greetd + Quickshell greeter (cage) / systemd-boot |

**At parity:** voxtype dictation (+ bar indicator), DND, idle-lock toggle,
nightlight toggle, cursor zoom, toggle top bar, keybindings cheatsheet,
notification dismiss, window grouping/tiling, monitor internal-display
toggle, universal clipboard, reminders, transcode/share, color picker,
first-class editor (jotain), multi-monitor workspaces.

## A4. Where marchyo goes BEYOND omarchy

- **BYOK AI desktop** — OpenRouter routing buckets, pi/claude-code,
  OpenViking context, MCP, Agent Skills. (omarchy 4.0 added an in-shell
  agents plugin, so this is narrowing, but marchyo's provider-agnostic BYOK
  routing is broader.)
- **Reproducibility & multi-platform** — one flake builds NixOS + nix-darwin
  + nix-on-droid; declarative rollback; disko/installer ISOs; SBOM +
  vulnerability scanning. Omarchy remains Arch-only and imperative.
- **Declarative, atomic system state** — the entire imperative
  install/remove/update surface is replaced by `nixos-rebuild` + flake pins.
- **Performance module** — declarative kernel/sysctl/IO tuning.

## A5. Omarchy surface N/A under NixOS

Not gaps — replaced by the declarative model:

- **Imperative package/system mutation** (`omarchy-install-*`, `-remove-*`,
  `-pkg-*`, `-update-*`, `-migrate`, channel switching, `refresh-*`
  config-copy-to-`~/.config`) → editing Nix modules + `nixos-rebuild`.
  marchyo generates all of `~/.config` from Nix; there is no copy-and-refresh
  step. (The documentation three-tree split — `docs/` + `manual/` + `plans/`
  — is the one part adopted.)
- **The git-repo plugin manager** → flake input + Home-Manager module at
  build time; the live third-party-extension affordance is intentionally
  absent (see A1).
- **omarchy's own RFCs** (`backup.md` off-site restic, `dots.md` config
  sync, `server.md` headless edition) — backup/dots are covered
  declaratively or out of scope; the server edition is out of scope.
