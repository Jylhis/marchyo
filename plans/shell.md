# Plan: Marchyo Shell — a unified Quickshell desktop

**Status: Phases 0–3 shipped and live-verified; Phases 4 (lock) and 5
(launcher) code-complete, each awaiting its live-verification pass** (the
`marchyo-shell` systemd user service runs the store package;
waybar/mako/SwayOSD are stood down, and with them vicinae — the shell's own
launcher answers Super+R / Super+period / Super+Ctrl+V). This document is the
design record plus the remaining work. The authoritative surface description
is [`shell/README.md`](../shell/README.md).

## Problem (original)

Marchyo's desktop UI was a composition of discrete Wayland components (waybar,
mako, SwayOSD, Vicinae, gum-TUI menus), each its own Home-Manager module,
process, and theme. The surfaces shared no design runtime, state, or process.
Omarchy solved this by collapsing the desktop into one long-running Quickshell
(QML) process. Marchyo built its own equivalent: a single, Jylhis-themed,
Nix-packaged shell — with one deliberate divergence: **no third-party plugin
system** (see below).

## Chosen architecture (as built)

One `quickshell -p <store-path>` process per session, launched as a
`marchyo-shell` graphical-session systemd user service, gated behind
`marchyo.shell.enable` (opt-in, default off, not cascaded from
`marchyo.desktop.enable`).

- **Simple monolith, no plugin machinery.** marchyo rejected omarchy's
  `PluginRegistry`/manifest/`shell.json` system: it exists almost entirely to
  discover and hot-reload third-party plugins from `~/.config`, which is the
  imperative, unsandboxed story this plan rejects. Surfaces are plain
  in-process QML components: the bar (`shell.qml` composes `Bar/` widgets per
  monitor inside `Variants { model: Quickshell.screens }`), the OSD
  (`Osd/Osd.qml`), summonable panels (`Panels/`), and notification toasts
  (`Notifications/`).
- **Shared singletons under `Services/`:** `PanelManager` (the one open-panel
  id + its output), `NotificationState` (DND + popup queue), `Audio`, `Power`,
  `NetworkStatus`, `SystemStats`, `Screens`, `Tooltip`, `Clock`,
  `KeyboardLayout`, `Caffeine`, `Dictation`. Seat-global state, processes, and
  timers live here, never in per-monitor widgets — pinned by a contract test.
- **One IPC surface:** a single stock `IpcHandler { target: "shell" }` in
  `shell.qml` (`togglePanel`/`openPanel`/`closePanels`, `toggleDnd`/`setDnd`/
  `clearNotifications`/`dismissLast`, `toggleBar`/`setBar`, `osdShow`, `ping`).
  Hyprland binds reach it via the wrapper (`marchyo-shell ipc -n call -- shell
  …`, self-targeting because the wrapper bakes `-p`). No custom bus.
- **Theming bridge:** `Commons/Color.qml`/`Style.qml`/`Config.qml` are
  generated from the Jylhis design system at build time by
  `packages/marchyo-shell/package.nix` (theme tokens, font-scale geometry,
  absolute `/nix/store` tool paths that are closure deps of the package).
  The checked-in `Commons/` files are usable source defaults — change the
  generators, not just the source files.
- **Packaging:** `packages/marchyo-shell/` copies `shell/` into the store and
  wraps `quickshell` with the runtime-env fixes (`TZDIR=/etc/zoneinfo` for Qt
  timezone lookup; `QT_QPA_PLATFORMTHEME=gtk3` for themed tray/notification
  icons). Linux block of `overlay.nix`; eval tests in
  `tests/eval/marchyo-shell.nix` assert the waybar/mako/swayosd mutual
  exclusions.

## Shipped (summary)

- **Phase 0 — packaging.** quickshell from nixpkgs, package + module + option
  + overlay + eval tests; tokens→QML bridge.
- **Phase 1 — bar.** Full waybar-parity Jylhis bar: workspaces (per-monitor,
  persistent 1–5), active window, clock (format-alt), tray (expander + SNI
  menus on right-click via `QsMenuAnchor`), audio, network (nmcli SSID+signal,
  colon-escaping fixed by `Commons/Format.js`), battery (full state set), CPU,
  bluetooth, power profile, keyboard layout (event-driven, no poll), DND,
  dictation, caffeine. Click-to-launch TUI actions; tooltips via a shared
  hover surface. Cutover: enabling the shell stands waybar down.
- **Phase 2 — OSD + panels.** Bottom-centred OSD (volume/mic-mute/brightness;
  brightness triggered by an IPC poke from the binds after `brightnessctl`,
  with the native sysfs watcher as fallback). SwayOSD retired. Four panels —
  audio / network / power / monitor — through `Ui/Panel.qml` +
  `Services/PanelManager` (mutually exclusive, anchored to the clicked bar's
  output), each keeping a TUI escape hatch.
- **Phase 3 — notifications.** `NotificationDaemon.qml` owns
  `org.freedesktop.Notifications` (body + markup subset + actions + images);
  toasts newest-first on the focused output, per-urgency expiry, click-to-
  dismiss, action pills, toast add/remove transitions, DND queue with a
  20-entry cap (critical bypass). DND is in-shell state; mako retired.
- **Hardening passes.** Seat-global work moved to `Services/` singletons
  (contract-tested: `Bar/` owns no Process/Timer/Connections/FileView/Socket);
  `voxtype --follow` restart with exponential backoff keyed on
  `onRunningChanged`; bounded collectors; two headless suites in
  `tests/shell/` (Format.js unit tests + 10 static QML contracts) wired into
  `nix flake check` Linux-only; offscreen harness
  (`just -f shell/Justfile check`) + qmlls/qmlformat tooling.
- **Live verification.** The shell has run as the daily driver on a real
  Hyprland host; live-observed defects were fixed on the spot (toast
  lifecycle + per-screen window binding, crash-looping property
  assignments, caffeine pgrep self-match, UPower 0–1 fraction scaling,
  glyph clashes). Remaining live-verify wrinkles should be filed as bugs,
  not tracked here.

## Remaining work

### Phase 4a — Lock surface (code-complete; live verification pending)

- **Status:** implemented on 2026-09-23 — `shell/Services/Lock.qml` (PAM state
  machine) + `shell/Lock/LockScreen.qml` (the `WlSessionLock`), `shell lock` /
  `shell lockState` IPC, SUPER+L and all three hypridle lock points cut over,
  hyprlock stood down on both the HM and NixOS sides (eval-tested in
  `tests/eval/marchyo-shell.nix`), and the idle screensaver guards on
  `lockState`. **Not yet live-verified on a real session — run the runbook
  below before calling it shipped.**
- **Goal (met):** replace hyprlock with an in-shell `WlSessionLock` surface
  behind the same mutual-exclusion cutover pattern used for
  waybar/swayosd/mako (`marchyo.shell.enable` stands the hyprlock wiring
  down).
- **Constraint:** a lock surface that fails to render or accept input locks
  the user out of the session, and the PAM/auth loop needs a real
  Hyprland/greetd host. Implementation is eval/harness/qmllint-verified; the
  live checks are the operator runbook.
- **Decisions:** hypridle remains the single idle authority — Quickshell's
  `IdleMonitor` is deliberately unused, so there is no second idle watcher
  (no double-lock at 300s) and `marchyo toggle idle` (which stops
  hypridle.service) keeps disabling idle lock. PAM config is the stock
  `login` stack (pam_unix + optional fprintd via the message protocol). No
  new `marchyo.*` option; `marchyo.shell.enable` gates everything.
- **Launcher:** shipped as Phase 5 (see below); this phase left vicinae
  alone.

#### Live-verification runbook (operator)

On the daily-driver Hyprland host, with `marchyo.shell.enable = true`, and a
fallback TTY logged in first (Ctrl+Alt+F3):

1. `nixos-rebuild switch --flake .#<host>` then
   `systemctl --user restart marchyo-shell`.
2. `marchyo-shell ipc -n call -- shell ping` → `ok`; `... shell lockState` →
   `unlocked`.
3. SUPER+L → clock + password card on **every** screen, caret on the focused
   one.
4. Correct password → unlocks. Wrong password → `Authentication failed`,
   field clears, retry works.
5. Idle: temporarily lower the hypridle 300s listener timeout (or wait
   5 min) → locks.
6. `systemctl suspend-then-hibernate` (hibernation hosts) → locks before
   sleep; password required on resume.
7. Lock manually, then stay idle past 120s — no screensaver animation burns
   under the lock.
8. If bricked: TTY → `loginctl terminate-session <id>` (loses the session)
   or reboot.
9. Never save QML edits while a dev-loop instance is locked (hot-reload
   destroys the lock).

### Phase 5 — Launcher (shipped; live verification pending)

- **Status:** implemented on 2026-09-23 — `shell/Services/Launcher.qml` (the
  open-mode singleton + the `pasteText` helper), `shell/Launcher/`
  (`LauncherWindow.qml` overlay with exclusive keyboard focus + the three
  mode views), `shell toggleLauncher/openLauncher/closeLauncher` IPC, and the
  SUPER+R / SUPER+period / SUPER+Ctrl+V binds cut over to it. Vicinae stands
  down on both the HM and NixOS sides with the shell on (eval-tested in
  `tests/eval/marchyo-shell.nix`); the cap_dac_override input-server wrapper
  goes with it — the in-shell launcher pastes via `wtype` after closing, no
  uinput helper. Emoji data is generated into `Commons/EmojiData.js` from
  `pkgs.unicode-emoji` at package build (gawk splice between in-file markers,
  no IFD); clipboard rows decode from `cliphist list` in Node-tested pure JS
  (`Commons/Cliphist.js`).
- **Vicinae stays in-tree** as the discrete-stack launcher
  (`marchyo.shell.enable = false`); wholesale removal of the discrete stack
  is a later milestone together with waybar/mako/swayosd.
- **Live-verify on a real session:** Super+R search/launch (incl. a webapps
  entry), Super+period emoji search → copy+type at the cursor, Super+Ctrl+V
  history → paste, Escape/outside-click close, open-on-focused-output on a
  multi-monitor host, fcitx5 preedit in the query field, `marchyo theme set`
  live-recolors the card.

### Live theme apply into the running shell

- **Goal:** `marchyo theme set` currently recolors ghostty, GTK, Hyprland,
  wallpaper, and (when the discrete stack is on) mako/waybar at runtime, but
  the running shell's `Color.qml` tokens are baked at build time — a runtime
  switch leaves the bar/panels/toasts on the old colors until the next
  service restart.
- **Mechanism (omarchy reference):** push the new palette over IPC into the
  running process (an `applyTheme` handler on the `shell` IpcHandler writing
  the generated token set into a runtime-writable Color source), rather than
  a service restart. Must not regress the current dconf/GTK variant fix
  (1982d89).
- **Files:** `shell/Commons/Color.qml` (runtime override path),
  `packages/marchyo-cli/…/commands/theme.ts` (poke after activation),
  eval/headless coverage where possible.

### Decisions (record)

- **No third-party plugins.** marchyo does not port omarchy's
  `PluginRegistry`/manifest/`shell.json` machinery; surfaces are plain
  in-process QML. A Nix-declared list can be added later if ever needed.
- **The shell ships its own launcher (Phase 5); the earlier "keep Vicinae"
  decision is reversed.** Vicinae remains a strong standalone launcher and
  stays in-tree as the discrete-stack launcher, but the shell-on desktop
  uses the in-shell surface — one process, one theme runtime, no privileged
  uinput helper. The reversal traded Vicinae's frecency and snippet
  expansion for zero extra privileges and design-token-native theming;
  revisit frecency inside the shell if daily use misses it.
- **Config surface:** everything bakes at build time from
  `marchyo.*` options (no runtime `shell.json`); revisit a runtime overlay
  only if runtime tweaks become needed.

### Divergences kept deliberately

- Marchyo's flat TUI aesthetic and bind namespace stay as-is (see
  [`omarchy-parity.md`](omarchy-parity.md) §A1).
