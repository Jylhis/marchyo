# shell/ — the marchyo Quickshell shell

A custom [Quickshell](https://quickshell.org) desktop shell: a single
long-running QML process replacing today's discrete
waybar + mako + swayosd + vicinae composition (bar, panels, OSD,
notifications, launcher; lock pending its live-verification pass). Design and
roadmap: **[../plans/shell.md](../plans/shell.md)**.

## Status — Phase 1 (bar) + Phase 2 (OSD + panels) + Phase 3 (notifications) + Phase 5 (launcher) done

A Jylhis-themed top bar at (near) waybar parity, built as a **simple monolith**:
`shell.qml` composes reusable widgets from `Bar/` (backed by the `Ui/` primitives
and the `Commons/` design-token singletons). Phases 2 and 3 add surfaces
**alongside** the bar as plain in-process components — the **OSD** (`Osd/`), the
summonable **panels** (`Panels/`, toggled from their bar widgets through the
`Services/` `PanelManager` singleton), and the **notification** toasts
(`Notifications/`, owning `org.freedesktop.Notifications`). There is deliberately
**no plugin registry or manifest system**: marchyo rejected the
third-party-plugin story (see `plans/shell.md`), so native Quickshell service
bindings plus (where a keybind must reach in) a stock `IpcHandler` suffice.

A hardening pass added **tooltips** (one shared hover surface under the bar),
**SNI tray menus** on right-click, **per-monitor workspaces** with waybar's
persistent 1–5, the full **battery state set** (charging / full / plugged-in),
shared `Services/` singletons for audio/power/network (one binding each for
bar, panel, and OSD), an **event-driven keyboard-layout widget** (no poll),
toast transitions, a DND queue cap, and a committed offscreen **type-check
harness** (`just -f shell/Justfile check`).

A second pass (see **[../plans/shell-research.md](../plans/shell-research.md)**,
a survey of ten public Hyprland/Quickshell projects) moved the last three
stateful widgets into `Services/` singletons: `shell.qml` builds the bar once per
screen, so a `Process` or `Timer` inside a widget was one subprocess **per
monitor** answering a seat-global question. `Bar/` widgets are now pure views,
the `voxtype --follow` stream **restarts with backoff** when it ends, and the
shell grew two **headless test suites** that `nix flake check` runs (see
[Tests](#tests)).

Gated behind `marchyo.shell.enable` (default off). Enabling it **replaces
waybar**, **SwayOSD**, **mako**, **hyprlock** (Phase 4), and **vicinae**
(Phase 5) — each mutually exclusive with its discrete counterpart (see
`modules/home/waybar.nix`, `modules/home/swayosd.nix`,
`modules/home/mako.nix`, `modules/home/hyprlock.nix`, and
`modules/home/vicinae.nix`) — so the shell owns the bar, the OSD,
notifications, the lock, and the launcher outright.

Layout:

```
shell/
  shell.qml            ShellRoot -> PanelWindow bar (left / centre / right)
  harness.qml          offscreen type-check harness (just check)
  Commons/
    qmldir             declares module qs.Commons
    Color.qml          design-token colours (palette + status); the Nix build
                       regenerates it for the host theme variant
    Style.qml          bar geometry + font sizes; regenerated from
                       marchyo.theme.fontScale, plus baked feature flags
    Theme.qml          runtime theme state (colors.json behind the
                       current-theme pointer; regenerates per host variant
                       in the Nix build)
    Config.qml         resolved external-tool paths; the Nix build regenerates it
                       with absolute /nix/store paths (dev default = PATH names)
    Format.js          pure parsing helpers (keymap short codes, nmcli records);
                       plain JS with a CommonJS guard so Node can unit-test it
    Match.js           pure fuzzy scoring (launcher: apps / emoji / clipboard)
    EmojiData.js       emoji catalog rows + parse; the Nix build regenerates the
                       rows from pkgs.unicode-emoji (dev subset checked in)
    Cliphist.js        pure cliphist helpers (quoted-printable payload decode)
  Ui/
    qmldir             declares module qs.Ui
    BarItem.qml        bar-segment primitive (padded label, hover, signals, tooltip)
    Panel.qml          summonable-panel base (layer-shell card + dismiss)
    PanelButton.qml    labelled pill control for panel bodies
    TooltipWindow.qml  the one tooltip surface (hover text below the bar)
  Bar/
    qmldir             declares module qs.Bar
    <Widget>.qml       one component per bar segment
  Osd/
    qmldir             declares module qs.Osd
    Osd.qml            volume/brightness/mic-mute overlay (replaces SwayOSD)
  Lock/
    qmldir             declares module qs.Lock
    LockScreen.qml     WlSessionLock surface (replaces hyprlock)
  Launcher/
    qmldir             declares module qs.Launcher
    LauncherWindow.qml the launcher overlay (exclusive keyboard focus layer)
    AppsView.qml       app search over DesktopEntries (replaces vicinae apps)
    EmojiView.qml      emoji grid over Commons/EmojiData.js
    ClipboardView.qml  cliphist history list + paste
  Services/
    qmldir             declares module qs.Services
    PanelManager.qml   singleton tracking the one open panel (mutual exclusion)
    SystemStats.qml    singleton: shared CPU/memory sampler (bar + monitor panel)
    NotificationState.qml  singleton: DND flag + live toast list (shared state)
    Audio.qml          singleton: shared Pipewire default sink/source + tracker
    Power.qml          singleton: shared UPower battery state + waybar-parity text
    NetworkStatus.qml  singleton: active device + nmcli SSID/signal/IP poll
    Dictation.qml      singleton: the one voxtype --follow stream (with restart)
    Caffeine.qml       singleton: the one keep-awake probe + toggle
    KeyboardLayout.qml singleton: the one hyprctl probe + activelayout listener
    Tooltip.qml        singleton: hovered item text/position (drives TooltipWindow)
    Lock.qml           singleton: lock state + the PAM auth machine (Phase 4)
    Launcher.qml       singleton: launcher open-mode state + the paste helper
  Panels/
    qmldir             declares module qs.Panels
    <Name>Panel.qml    one summonable panel (audio / network / power / monitor)
  Notifications/
    qmldir             declares module qs.Notifications
    NotificationDaemon.qml  owns org.freedesktop.Notifications (replaces mako)
    NotificationList.qml    top-right layer-shell toast stack
    NotificationPopup.qml   one themed toast card (delegate)
```

The shell also declares a single stock `Quickshell.Io.IpcHandler` (target
`shell`) in `shell.qml` so Hyprland keybinds can summon panels and poke the OSD;
see [Keybind summons](#keybind-summons) below.

### Widgets

Most widgets bind to native Quickshell services; the rest shell out to tools whose
absolute `/nix/store` paths are baked into `Commons/Config.qml` at build time (see
below), so nothing depends on the session `PATH`.

| Widget | Backing service / tool |
| --- | --- |
| SessionWidget | static "marchyo" label |
| WorkspacesWidget | `Quickshell.Hyprland` (per-monitor; persistent 1–5, waybar parity) |
| ClockWidget | `Quickshell.SystemClock` (click = toggle long / ISO-week form) |
| TrayWidget | `Quickshell.Services.SystemTray` (`·` expander, click = show/hide; right-click = SNI menu via `QsMenuAnchor`) |
| DictationWidget | `Services/Dictation` → one `voxtype status --follow` stream (click = toggle); baked on/off via `Style.dictationIndicator` |
| CaffeineWidget | `Services/Caffeine` → `pgrep` probe + `marchyo toggle caffeine` |
| ThemeWidget | Commons/Theme → colors.json behind the current-theme pointer (click = marchyo theme next) |
| DndWidget | in-shell `Services/NotificationState` (click = toggle DND) |
| KeyboardLayoutWidget | `Services/KeyboardLayout` → `hyprctl devices` probe + `Hyprland` `activelayout` raw events (no poll) |
| BluetoothWidget | `Quickshell.Bluetooth` (click = bluetui) |
| NetworkWidget | `Quickshell.Networking` + `Services/NetworkStatus` nmcli poll (click = network panel) |
| AudioWidget | `Services/Audio` → `Quickshell.Services.Pipewire` (scroll = volume, right-click = mute, click = audio panel) |
| CpuWidget | `Services/SystemStats` (`/proc/stat`) (click = monitor panel) |
| PowerProfileWidget | `Quickshell.Services.UPower` `PowerProfiles` (click = cycle) |
| BatteryWidget | `Services/Power` → `Quickshell.Services.UPower` (click = power panel) |

Most widgets also carry a hover **tooltip** (waybar parity: network shows
IP/interface, battery the power draw `4.2W↓ 87%`, bluetooth the connected
devices, power-profile the profile name, …). `BarItem.tooltipText` feeds the
shared `Services/Tooltip` singleton; the one `Ui/TooltipWindow` layer surface
renders it below the bar, centered under the hovered item on its screen.

TUI launches use `ghostty --class=org.omarchy.* -e <tool>` so Hyprland's existing
float rule applies — the same classes and commands as `modules/home/waybar.nix`.

### Tool-path baking

`Commons/Config.qml` is a generated singleton of resolved binary paths
(`packages/marchyo-shell/package.nix`, same idiom as `Color.qml`/`Style.qml`). The
tool packages arrive as `callPackage` args; `lib.getExe` resolves them. The
checked-in `Config.qml` holds bare `PATH` names so `quickshell -p shell` still runs
standalone; the build overwrites it.

### OSD (on-screen display)

`Osd/Osd.qml` is a single bottom-centred, click-through overlay that flashes the
current level whenever it changes, replacing SwayOSD. Its triggers are mostly
**native and pull-based**:

- **volume / mic mute** — `Quickshell.Services.Pipewire` bindings on the default
  sink/source (shared with the bar and the audio panel through
  `Services/Audio`); a `Connections` on their `audio` objects shows the overlay
  on any volume or mute change (guarded so the startup binding storm doesn't
  flash it). Unmuting the mic shows its live level as a bar; volume reads up to
  150% like the bar's scroll ceiling (the filled bar caps at 100% of its
  track, the label tells the truth).
- **brightness** — the primary path is the **keybind IPC poke**: the Hyprland
  brightness binds (see `modules/home/hyprland.nix`) run `brightnessctl` and
  then `marchyo-shell ipc -n call -- shell osdShow BRT <pct> true` with the
  resulting level. This is deliberate: sysfs attribute writes signal
  `POLLPRI`, which `FileView`'s watcher (inotify) does not see on most hosts.
  A native `FileView` (`watchChanges`) on the first `/sys/class/backlight`
  node remains as a best-effort fallback for brightness changes made outside
  the keybinds (other tools, external monitors' DDC).

The Hyprland media keys therefore keep doing the *actual* change (silent
`wpctl` / `brightnessctl` + the poke for brightness; see
`modules/home/hyprland.nix`). Enabling the shell stands SwayOSD down
(`modules/home/swayosd.nix`); the backlight udev write-access from
`modules/nixos/osd.nix` still applies, so `brightnessctl` keeps working.

### Panels

Summonable cards under the bar, one per cluster, opened by clicking the matching
bar widget. The whole "registry" is `Services/PanelManager.qml`: a singleton
holding the one open panel's id, so they are **mutually exclusive** (opening one
closes any other) with no manifest system or IPC. A bar widget's click calls
`PanelManager.toggle(id)`; `Ui/Panel.qml` (a full-screen, transparent layer-shell
overlay that dismisses on outside click) binds its visibility to
`PanelManager.openId === id` and only materialises a surface while open.

| Panel | Opened by | Backing service | Contents |
| --- | --- | --- | --- |
| AudioPanel | AudioWidget | `Pipewire` | volume -/+, mute, output-device picker, `wiremix` escape |
| NetworkPanel | NetworkWidget | `Networking` + `nmcli` | connection status, SSID/signal, `nmtui` escape |
| PowerPanel | BatteryWidget | `UPower` + `PowerProfiles` | battery detail, profile selector, `power menu` escape |
| MonitorPanel | CpuWidget | `Services/SystemStats` + `df` + hwmon | CPU / mem / disk / temp meters, `btop` escape |

Each panel reuses the exact native bindings of its bar widget (via the shared
`Services/` singletons — `Audio`, `Power`, `NetworkStatus`, `SystemStats`) and
keeps a button to the corresponding TUI/menu for anything the panel doesn't
cover. Panels currently render on the default screen (per-output panels are
deferred).

The MonitorPanel adds two data sources the other panels don't: disk-use of `/`
(there is no native statvfs binding, so it shells out to the baked `Config.df`,
polled only while the panel is open) and CPU temperature (the first
`/sys/class/hwmon` node whose `name` is a known CPU sensor — `coretemp` /
`k10temp` / `zenpower` / `cpu_thermal` — since `thermal_zone0` is often the
motherboard, not the package). CPU and memory come from the shared
`Services/SystemStats` singleton, which owns the single `/proc/stat` +
`/proc/meminfo` sampler that the bar's CpuWidget reads too.

### Keybind summons

`shell.qml` declares one stock `IpcHandler { target: "shell" }` exposing
`togglePanel(id)` / `openPanel(id)` / `closePanels()`, the notification controls
`toggleDnd()` / `setDnd(on)` / `clearNotifications()`, and `osdShow(...)` — the
last is the brightness OSD's **primary trigger** (the brightness binds poke it
after every `brightnessctl` change; see the OSD section). Hyprland binds (added
by `modules/home/hyprland.nix` and `modules/home/window-toggles.nix` only when
the shell is enabled) reach the running process through the wrapped binary:

```
marchyo-shell ipc -n call -- shell togglePanel monitor
```

The `marchyo-shell` wrapper bakes its own `-p <store-path>`, so the call
self-targets the running instance (no instance id to track). Default binds:
`SUPER+SHIFT+V` audio, `SUPER+SHIFT+N` network, `SUPER+SHIFT+B` power,
`SUPER+SHIFT+M` monitor; the launcher summons (`toggleLauncher apps|emoji|
clipboard`) ride `SUPER+R` / `SUPER+period` / `SUPER+CTRL+V`. The DND toggle
(`SUPER+CTRL+comma`) and dismiss-all
(`SUPER+CTRL+SHIFT+comma`) binds route through `toggleDnd` / `clearNotifications`
when the shell is on, and fall back to the CLI/mako when it is off. This is the
only IPC in the shell; there is no custom bus (see `plans/shell.md`).

### Notifications

`Notifications/NotificationDaemon.qml` instantiates a Quickshell
`NotificationServer` that owns `org.freedesktop.Notifications`, replacing mako.
It advertises body + limited markup + action buttons + an app image (no inline
reply, no persistence). On each incoming notification it retains the object
(`tracked = true`, so the toast and its actions stay live) and hands it to the
shared `Services/NotificationState` singleton, which applies the do-not-disturb
policy and the visible cap. `NotificationList.qml` is a top-right layer-shell
stack that renders `NotificationState.popups` newest-first;
`NotificationPopup.qml` is one themed card (sharp corners + a 2px urgency-coloured
border, matching mako's aesthetic) with its own auto-expire timer, click-to-
dismiss, and action pills.

Do-not-disturb is **in-shell state** on `NotificationState` (no `makoctl`, no
poll). The bar's DndWidget binds to and toggles it directly; the keybind and CLI
reach it over IPC (above). Under DND, non-critical notifications are queued and
suppressed (no toast), then flushed back when DND clears (mako's
`mode=do-not-disturb` "invisible" semantics), while critical ones always show.
The queue is capped (`maxQueued` = 20; the oldest overflow is dismissed, not
re-shown) so a long DND stretch cannot pile up unbounded state. Per-urgency
timeouts mirror mako: low/normal 5s, critical persistent. The toast stack
animates: toasts fade/slide in, fade out, and reshuffle smoothly (`Column`
positioner transitions — mako's toast feel).

| Piece | Backing |
| --- | --- |
| NotificationDaemon | `Quickshell.Services.Notifications` `NotificationServer` |
| NotificationList | layer-shell `PanelWindow`, top-right, content-sized |
| NotificationPopup | `Notification` fields; actions via `NotificationAction.invoke()` |
| DND state | `Services/NotificationState` singleton (shared) |

> Live-verify note: D-Bus name acquisition, real toast rendering/stacking,
> action round-trips, `Quickshell.iconPath` icon resolution, and the
> `bodyMarkupSupported` HTML subset can only be confirmed on a Wayland host with
> mako actually stood down.

### Lock

`Lock/LockScreen.qml` is a compositor-level `WlSessionLock`
(ext-session-lock-v1) with in-process PAM authentication — Phase 4, replacing
hyprlock under the same mutual-exclusion cutover as waybar/mako/SwayOSD.
`Services/Lock` owns the state machine: one `PamContext` (config `login`)
drives the prompt/retry loop, and `locked = false` happens in exactly one
place — a successful authentication. Trigger paths:

- `SUPER+L` and hypridle's lock points (`lock_cmd`, `before_sleep_cmd`, the
  300s listener in `modules/home/hypridle.nix`) call
  `marchyo-shell ipc -n call -- shell lock`. hypridle stays the single idle
  authority so `marchyo toggle idle` keeps disabling idle lock; Quickshell's
  `IdleMonitor` is deliberately unused (no second idle watcher, no
  double-lock race).
- The idle screensaver asks `shell lockState` before launching — the same
  guard it had for a running hyprlock.

Each screen gets one `WlSessionLockSurface` (clock + password card, Jylhis
tokens); the focused output's field takes keyboard focus, any field can be
clicked to claim it. Focus and `pam.start()` are gated on `secure`
(compositor-confirmed coverage), per the upstream docs.

> **Testing warning:** destroying the shell (crash, or a hot-reload from the
> dev loop) while locked leaves a conformant compositor showing a solid
> color — by design. Never edit QML while a dev instance is locked, and keep
> a TTY logged in when live-testing (runbook in `plans/shell.md`).

### Launcher

`Launcher/LauncherWindow.qml` is the Phase 5 launcher: a full-screen
transparent overlay (the Ui/Panel dismiss idiom) with a centered card, one
shared query field, and three mode views — replacing vicinae under the same
mutual-exclusion cutover as waybar/mako/SwayOSD/hyprlock. `Services/Launcher`
holds the open-mode state ("" / "apps" / "emoji" / "clipboard"); the surface
takes `WlrKeyboardFocus.Exclusive` while open and closes on Escape,
outside click, or focus loss.

| Mode | Bind | Backing | Activate |
| --- | --- | --- | --- |
| apps | `SUPER+R` | `Quickshell.DesktopEntries` (webapps' `xdg.desktopEntries` flow in) | `DesktopEntry.execute()` |
| emoji | `SUPER+period` | `Commons/EmojiData.js` — rows generated from `pkgs.unicode-emoji`'s emoji-test.txt at package build (dev subset checked in; fully-qualified entries, Component group dropped) | copy + type |
| clipboard | `SUPER+CTRL+V` | one `cliphist list` per open (fed by the wl-paste watchers in `modules/home/hyprland.nix`); payloads decode in `Commons/Cliphist.js` | copy + type |

Paste (emoji/clipboard) goes through `Services/Launcher.pasteText`:
`Quickshell.clipboardText` for the copy, then `wtype` after a 0.25 s settle
— the launcher closes first so wtype delivers to the previously focused
window. No privileged helper: vicinae's `cap_dac_override` uinput wrapper
stands down with the cutover (gated in `modules/nixos/launcher.nix`). The
text travels as argv (`exec "$0" "$1"`), never through shell interpolation.

Search scoring is `Commons/Match.js` (prefix > word-start > scattered
subsequence; empty query = name order), unit-tested from Node like Format.js.

### Waybar parity

The bar now matches waybar's full segment set, including the two former gaps:
the **tray expander** (a `·` toggle that shows/hides the icons, so the bar stays
compact when the tray is idle) and the **clock `format-alt` toggle** (left-click
switches between `Sat 22 Aug · 14:30` and the long `22 August W34 2025` form with
ISO week). Since then a hardening pass closed the remaining behavioural gaps:
tooltips (see above), SNI tray menus on right-click (`QsMenuAnchor`, with
menu-only items opening their menu on left-click), per-monitor workspaces plus
the persistent 1–5 (waybar's `persistent-workspaces`), and the full battery
state set (charging / full / plugged-in). Nothing waybar renders is missing.

The right-hand readouts are **compact Nerd-font glyph + value** rather than word
labels (e.g. `󰕾 100`, `󰁹 87`, `󰓅 45`, `󰤨 72`), rendered in `BlexMono Nerd Font`
(the `fontFamily` in `Commons/Style.qml`, installed system-wide via
`modules/nixos/fonts.nix`). This keeps the right group narrow enough to clear the
screen-centered clock on small outputs; the verbose text (`Volume 100%`,
`CPU 45%`, SSID/signal, …) lives in each widget's hover tooltip.

## Development

Run the tree directly for a fast QML iteration loop (no rebuild):

```bash
quickshell -p shell          # from the repo root
# or, the wrapped, theme-baked package:
nix run .#marchyo-shell
# or, via the dev recipe (also stops the store-backed user service first):
just -f shell/Justfile dev
```

The checked-in `Commons/Color.qml` / `Commons/Style.qml` are the Jylhis Dark
`fontScale 1.0` defaults so the dev loop works standalone; the Nix build
overwrites both for the host's `marchyo.theme.variant` and `fontScale`.

### Editor tooling (qmlls)

`import qs.*` is a Quickshell convention: the config root is the `qs` module
namespace. Quickshell 0.3.0's built-in tooling support mirrors the scanned
`.qml` files into a runtime vfs (`/run/user/$UID/quickshell/vfs/…`) and drops a
`.qmlls.ini` symlink into `shell/` — but that mirror contains **no `qmldir`
files**, so qmlls can never resolve `qs.*` through it. (It's a runtime
artifact: untracked, and recreated by any `quickshell -p shell` run.)

Instead, `devenv.nix` builds a stable alias at `.devenv/qml-modules/qs ->
shell/` (`enterShell`) and exports

```
QML_IMPORT_PATH = .devenv/qml-modules : quickshell/lib/qt-6/qml : qtdeclarative/lib/qt-6/qml
```

so the checked-in per-directory `qmldir`s (`module qs.Commons`, `qs.Bar`, …)
resolve `qs.*` for qmlls/qmllint exactly the way the running shell resolves
them, and `Quickshell.*` / `QtQuick*` resolve from the store paths. Any editor
that launches qmlls with `-E` from the devenv shell (eglot, neovim-lsp, …)
inherits this; inside the devenv shell you can check by hand:

```bash
qmllint -E shell/shell.qml   # expect no "Failed to import" lines
```

### Runtime environment

The `marchyo-shell` wrapper bakes two env vars so the shell never depends on
session-env quirks (the dev recipe exports the same pair):

- `TZDIR=/etc/zoneinfo` — Qt's tz database search only probes
  `/usr/share/zoneinfo`, which doesn't exist on NixOS, so without this Qt
  can't map `/etc/localtime` to an IANA name and warns
  *"Unable to determine system time zone"* on D-Bus `QDateTime` conversions.
  `/etc/zoneinfo` follows the live symlink, so auto-timezone changes apply.
  Harmless (plain fallback to the old behaviour) on hosts without it.
- `QT_QPA_PLATFORMTHEME=gtk3` — the session value is typically `qt5ct` (HM's
  qt module via stylix), which has no Qt6 plugin; the shell then resolves
  themed icons against `hicolor` and tray/notification icons fail to load.
  The `gtk3` platform theme reads marchyo's own GTK settings (`Adwaita`).

### Tests

Three layers, split by what each can reach:

| Suite | Runs where | Covers |
| --- | --- | --- |
| `tests/shell/format-test.js` | `nix flake check`, or `node tests/shell/format-test.js` | `Commons/Format.js` — the shell's pure parsing (keymap short codes, `nmcli -t` records) |
| `tests/shell/launcher-test.js` | `nix flake check`, or `node tests/shell/launcher-test.js` | the launcher's pure JS — `Match.js` scoring, `EmojiData.js` parsing, `Cliphist.js` quoted-printable/UTF-8 decoding |
| `tests/shell/contracts-test.sh` | `nix flake check`, or `bash tests/shell/contracts-test.sh` | static cross-file agreements: qmldir completeness, `Bar/` widgets owning no runtime state, `Services/` all being singletons, the `Config.<tool>` → `package.nix` chain, and every `marchyo-shell ipc … -- shell <fn>` call in `modules/home/` resolving |
| `just -f shell/Justfile check` | a machine with Quickshell | the tree actually parses, binds and loads |

The first three are the reason `Commons/*.js` files are plain `.js` modules with a
CommonJS guard at the bottom rather than QML functions: QML logic needs Quickshell
and a Qt platform plugin to run at all, so none of it is reachable from
`nix flake check`, while a JavaScript module is imported unchanged by QML *and*
loadable by Node. Anything in `Format.js` must therefore stay pure — no Qt types,
no I/O — and it must not gain a `.pragma library` line, which QML accepts and Node
rejects. Both rules are pinned by the contract suite.

The contracts exist because QML resolves imports, qmldir entries and `IpcHandler`
method names at **runtime**: a rename on one side of any of those agreements
otherwise shows up as a broken bar on a user's desktop rather than a failed build.
Every contract was verified to fail against a deliberate mutation before being
kept — a check that moves with the thing it checks can never fail.

To type-check the QML itself without a Wayland compositor, run the committed
harness under the offscreen platform:

```bash
just -f shell/Justfile check
```

`harness.qml` instantiates the Ui primitives and every bar widget (exercising
the Commons and Services singletons plus the native service bindings); the
Panels/OSD/notification surfaces can't load offscreen (they need a layer-shell
backend), so they are covered by the dev loop and `qmlformat` (treefmt) for
syntax. "Configuration Loaded" with no `WARN`/`ERROR` from the shell's own
files means the tree parses and binds cleanly.
