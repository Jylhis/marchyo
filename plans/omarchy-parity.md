# Omarchy → Marchyo: gap analysis + status

Comparison of [basecamp/omarchy](https://github.com/basecamp/omarchy) against
marchyo, refreshed against omarchy **4.0.0.alpha** (2026-08-22 checkout).

Historical note: the 2026-07 pre-4.0 parity batch (PRs #107–#120) and the
Quickshell-era response (marchyo's own shell, Phases 0–3 — bar, OSD, panels,
notifications — shipped and live-verified) have closed most of the original
gaps. This document now tracks what is still genuinely open. The shell's
design record is [`shell.md`](shell.md); its research backlog is
[`shell-research.md`](shell-research.md).

## Context

Marchyo is a NixOS re-implementation of the ideas in omarchy (DHH/Basecamp's
opinionated Arch + Hyprland distro). Both inventories were taken from current
sources: omarchy at `4.0.0.alpha`, marchyo from the working checkout.

**Omarchy today** is one long-running Quickshell (QML) process
(`omarchy-shell`) hosting bar, notifications, OSD, lock, menus, panels,
launcher, clipboard and emoji pickers, polkit agent, background/theme pickers
as **manifest.json plugins** over an IPC bus, driven by a 431-script imperative
`bin/omarchy-*` Arch overlay.

**Marchyo today** composes its own Quickshell shell (`shell/`, default off,
see [`shell.md`](shell.md)) — a simple monolith with no plugin machinery —
plus Vicinae (launcher/emoji/clipboard), hyprlock, and the `marchyo` CLI as
the command surface. Everything else is declarative NixOS: the whole
install/remove/update/migrate category is replaced by `nixos-rebuild` +
flake pins with rollback (see "N/A under NixOS" below).

## A1. Deliberate divergences (NOT gaps)

- **No third-party plugin system.** marchyo rejected omarchy's
  git-repo-into-`~/.config` plugin model; the shell is plain in-process QML
  and all extension is Nix-declared. The imperative `omarchy plugin
  add/update/remove` surface is intentionally absent.
- **Flat TUI aesthetic.** marchyo forces `rounding=0`, `gaps=0`, `border=2`,
  `animations=off`, no blur/shadow, and omits omarchy's runtime
  transparency/gaps/aspect toggles.
- **App-launch keybind namespace.** omarchy launches on `SUPER+SHIFT+<letter>`;
  marchyo on plain `SUPER+<letter>`. The whole map is shifted, not missing.
- **Launcher engine.** marchyo uses Vicinae (`SUPER+R`); omarchy's Walker +
  Elephant were retired into its menu plugin's `apps` provider. Different
  engines, deliberate.
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
2. **Lock screen as a themed shell surface.** omarchy's `lock` plugin renders
   inside the shell with per-theme assets; marchyo uses hyprlock with
   rebuild-time theming. This is shell Phase 4a — tracked in
   [`shell.md`](shell.md).
3. **Live theme apply without rebuild.** omarchy pushes theme changes into
   the running shell via `applyTheme` IPC over its 22 themes. Marchyo has
   N-theme runtime switching (`marchyo.theme.themes` + `marchyo theme
   set/next`, ephemeral overlay, wallpaper + ghostty/GTK/Hyprland recolored
   live) — but the running shell's own colors are baked at build time and
   follow only after a service restart. Tracked in [`shell.md`](shell.md).
4. **System-integration extras** — first-run onboarding, lifecycle hooks
   (`battery-low`, `theme-set`, `post-boot`), crash capture, gaming/hardware
   helpers. None ported; each would need a declarative (module/timer) shape
   first. Low priority unless a concrete need appears.
5. **Per-theme keyboard RGB / backgrounds per theme.** omarchy ships
   per-theme `keyboard.rgb` and `backgrounds/`; marchyo has one
   theme-tied wallpaper per theme plus `marchyo bg set`. Niche.

Previously-listed gaps now closed: notifications as a persistent server
(shell Phase 3 owns the bus; persistence/history still open — see
[`shell-research.md`](shell-research.md) backlog), rich connectivity panels
(shell Phase 2: audio/network/power/monitor; tailscale/dropbox/speedtest/
wifi-qr panels still absent), calculator (`modules/home/qalculate.nix` ships
a qalc REPL), OCR-on-capture (`marchyo capture ocr`), transcode
(`marchyo transcode`), share (`marchyo share`), reminders (`marchyo
reminder`), screensaver/idle (tte + hypridle at behavioral parity).

## A3. Present-but-DIFFERENT (kept for orientation)

| Capability | Omarchy 4.0.0.alpha | Marchyo |
|---|---|---|
| Bar | `omarchy.bar` plugin | marchyo shell `Bar/` (default off; waybar otherwise) |
| Notifications | plugin, persistent history | marchyo shell Phase 3 (no history yet); mako otherwise |
| OSD | plugin, fed by `omarchy-*` poke | marchyo shell `Osd/` (IPC poke + sysfs fallback); SwayOSD otherwise |
| Lock screen | `lock` plugin | hyprlock (`SUPER+CTRL+L`) |
| App launcher | menu plugin `apps` provider | Vicinae (`SUPER+R`) |
| Emoji picker / clipboard | shell plugins | Vicinae + cliphist |
| Command/system menu | JSONC QML menu | `marchyo menu` / `marchyo-power-menu` gum TUIs |
| Media keys | shell `media` service | mpris/playerctl |
| Theme switch | runtime picker, 22 themes, live `applyTheme` | `marchyo.theme.{variant,scheme,themes}` + runtime ephemeral overlay |
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
