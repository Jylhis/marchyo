# Marchyo Shell — a unified Quickshell desktop

The marchyo shell is a single Quickshell (QML) process that provides the bar,
OSD, panels, notifications, lock surface, and launcher for the Hyprland
desktop. It is gated behind `marchyo.shell.enable` (opt-in, default off, not
cascaded from `marchyo.desktop.enable`); enabling it stands the discrete
stack (waybar, mako, SwayOSD, Vicinae, hyprlock) down. This document is the
design record (architecture and the decisions that shape it) plus the
remaining work. The authoritative surface description is
[`shell/README.md`](../shell/README.md).

## Architecture

One `quickshell -p <store-path>` process per session, launched as a
`marchyo-shell` graphical-session systemd user service.

- **Simple monolith, no plugin machinery.** The shell has no
  `PluginRegistry`/manifest/`shell.json` system. Surfaces are plain
  in-process QML components: the bar (`shell.qml` composes `Bar/` widgets per
  monitor inside `Variants { model: Quickshell.screens }`), the OSD
  (`Osd/Osd.qml`), summonable panels (`Panels/`), notification toasts and the
  notification centre (`Notifications/`), the lock surface (`Lock/`), and the
  launcher (`Launcher/`).
- **Shared singletons under `Services/`:** `PanelManager` (the one open-panel
  id + its output), `NotificationState` (DND + popup queue + history),
  `Audio`, `Power`, `NetworkStatus`, `SystemStats`, `Screens`, `Tooltip`,
  `Clock`, `KeyboardLayout`, `Caffeine`, `Dictation`, `Mpris`, `Peripherals`,
  `Lock` (PAM state machine), `Launcher`. Seat-global state, processes, and
  timers live here, never in per-monitor widgets — pinned by a contract test.
- **One IPC surface:** a single stock `IpcHandler { target: "shell" }` in
  `shell.qml` (panel toggles, DND/notification controls, bar toggle, OSD,
  lock/`lockState`, launcher toggles, `ping`). Hyprland binds reach it via the
  wrapper (`marchyo-shell ipc -n call -- shell …`, self-targeting because the
  wrapper bakes `-p`). No custom bus.
- **Theming bridge:** `Commons/Color.qml` delegates its tokens to
  `Commons/Theme.qml`, a runtime reader that watches the `colors.json` behind
  the `~/.config/marchyo/current-theme` pointer; `marchyo theme set/next`
  repoints it and every surface binding `Color.*` (bar, panels, toasts, lock,
  launcher) live-recolors with no service restart. `Style.qml`/`Config.qml`
  are generated from the Jylhis design system at build time by
  `packages/marchyo-shell/package.nix` (font-scale geometry, palette-
  independent appearance scale axes, absolute `/nix/store` tool paths that are
  closure deps of the package). The checked-in `Commons/` files are usable
  source defaults — change the generators, not just the source files.
- **Packaging:** `packages/marchyo-shell/` copies `shell/` into the store and
  wraps `quickshell` with the runtime-env fixes (`TZDIR=/etc/zoneinfo` for Qt
  timezone lookup; `QT_QPA_PLATFORMTHEME=gtk3` for themed tray/notification
  icons). Linux block of `overlay.nix`; eval tests in
  `tests/eval/marchyo-shell.nix` assert the waybar/mako/swayosd/vicinae/
  hyprlock mutual exclusions.

## Surfaces

- **Bar** (`Bar/`): waybar-parity Jylhis bar — workspaces (per-monitor,
  persistent 1–5), active window, clock, tray (SNI menus via `QsMenuAnchor`),
  audio, network, battery (continuous gradient), CPU, bluetooth, power
  profile, keyboard layout, DND, dictation, caffeine, MPRIS media, wireless
  peripherals, and a microphone-in-use indicator. Click-to-launch TUI actions;
  tooltips via a shared hover surface.
- **OSD** (`Osd/`): bottom-centred volume/mic-mute/brightness, on the focused
  output.
- **Panels** (`Panels/`): audio / network / power / monitor, mutually
  exclusive via `Services/PanelManager`, anchored to the clicked bar's output,
  each with a TUI escape hatch. The audio panel exposes per-application streams
  with live meters.
- **Notifications** (`Notifications/`): owns `org.freedesktop.Notifications`
  (body + markup subset + actions + images); newest-first toasts on the
  focused output, a notification centre with an unread badge, history that
  persists across restarts, per-sender rules, and a DND queue.
- **Lock** (`Lock/`): an in-shell `WlSessionLock` (PAM auth via
  `Services/Lock.qml`), bound to SUPER+L and all hypridle lock points; hypridle
  remains the single idle authority (`IdleMonitor` deliberately unused, so
  `marchyo toggle idle` still disables idle lock).
- **Launcher** (`Launcher/`): apps / emoji / clipboard, answering SUPER+R /
  SUPER+period / SUPER+Ctrl+V, with exclusive keyboard focus and fuzzy scoring.
  Pastes via `wtype` after closing, no privileged uinput helper. Emoji data is
  baked into `Commons/EmojiData.js` from `pkgs.unicode-emoji`; clipboard rows
  decode from `cliphist list`.

## Remaining work

- **Launcher multi-monitor / IME confirmation.** Confirm open-on-focused-output
  on a multi-monitor host and fcitx5 preedit in the query field.
- **Wholesale removal of the discrete stack.** Vicinae, waybar, mako, and
  SwayOSD stay in-tree as the `marchyo.shell.enable = false` fallback;
  dropping them entirely is a later milestone.
- Shell functionality backlog (lock-keys widget, persistent per-app audio
  routing, dictation silence gate) lives in
  [`shell-research.md`](shell-research.md).

## Design decisions

- **No third-party plugins.** Surfaces are plain in-process QML; a
  Nix-declared list can be added later if ever needed.
- **The shell ships its own launcher.** Vicinae remains a strong standalone
  launcher and stays in-tree as the discrete-stack fallback, but the shell-on
  desktop uses the in-shell surface — one process, one theme runtime, no
  privileged uinput helper. Revisit frecency inside the shell if daily use
  misses it.
- **Config bakes at build time** from `marchyo.*` options (no runtime
  `shell.json`); revisit a runtime overlay only if runtime tweaks become
  needed.
- **Flat TUI aesthetic and bind namespace** stay as-is (see
  [`omarchy-parity.md`](omarchy-parity.md) §A1).
