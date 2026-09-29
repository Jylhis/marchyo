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

- **Monolith with a build-time plugin platform.** The shell is an in-process
  monolith, but it now carries a build-time (Option A) plugin platform and a
  generated runtime config — no runtime discovery, no hot-reload. Plugins are
  Nix-declared via `pkgs.mkMarchyoShellPlugin` (`marchyo.shell.plugins`),
  validated and baked into the store shell, and listed in a generated
  `Commons/PluginIndex.qml`; the bar layout is data-driven from
  `Commons/ShellConfig` (a generated, read-only `~/.config/marchyo/shell.json`
  whose default reproduces the historical static order). First-party surfaces
  stay plain in-process QML: the bar (`shell.qml` composes `Bar/` widgets per
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

- **Wholesale removal of the discrete stack.** Vicinae, waybar, mako, and
  SwayOSD stay in-tree as the `marchyo.shell.enable = false` fallback;
  dropping them entirely is a later milestone.
- Shell functionality backlog (lock-keys widget, persistent per-app audio
  routing, dictation silence gate) lives in
  [`shell-research.md`](shell-research.md).

## Design decisions

- **Third-party plugins, build-time only.** Plugins are a Nix-declared list
  (`marchyo.shell.plugins`, built by `pkgs.mkMarchyoShellPlugin`) baked into the
  store shell — reproducible and reviewable in the flake, never fetched or
  discovered at runtime. The manifest schema matches upstream omarchy for
  interop; a compat shim covers simple omarchy bar widgets.
- **The shell ships its own launcher.** Vicinae remains a strong standalone
  launcher and stays in-tree as the discrete-stack fallback, but the shell-on
  desktop uses the in-shell surface — one process, one theme runtime, no
  privileged uinput helper. Revisit frecency inside the shell if daily use
  misses it.
- **Config is generated, read at runtime.** `marchyo.shell.settings` is
  serialized to a generated, read-only `~/.config/marchyo/shell.json` that the
  shell reads live (watched + polled, like `colors.json`), so a rebuild's new
  bar layout / idle timings apply without restarting the shell. Still fully
  build-time-generated (reproducible); it is not hand-edited.
- **Flat TUI aesthetic and bind namespace** stay as-is (see
  [`omarchy-parity.md`](omarchy-parity.md) §A1).
