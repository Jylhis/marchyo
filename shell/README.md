# shell/ — the marchyo Quickshell shell

A custom [Quickshell](https://quickshell.org) desktop shell: a single
long-running QML process that will eventually replace today's discrete
waybar + mako + swayosd + vicinae composition (bar, panels, OSD,
notifications, lock). Design and roadmap: **[../plans/shell.md](../plans/shell.md)**.

## Status — Phase 1 (bar) + Phase 2 (OSD + panels) + Phase 3 (notifications) done

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

Gated behind `marchyo.shell.enable` (default off). Enabling it **replaces
waybar**, **SwayOSD**, and **mako** (each mutually exclusive with its discrete
counterpart — see `modules/home/waybar.nix`, `modules/home/swayosd.nix`, and
`modules/home/mako.nix`), so the shell owns the bar, the OSD, and notifications
outright. Vicinae (launcher) and the lock/screensaver stay for Phase 4.

Layout:

```
shell/
  shell.qml            ShellRoot -> PanelWindow bar (left / centre / right)
  Commons/
    qmldir             declares module qs.Commons
    Color.qml          design-token colours (palette + status); the Nix build
                       regenerates it for the host theme variant
    Style.qml          bar geometry + font sizes; regenerated from
                       marchyo.theme.fontScale, plus baked feature flags
    Config.qml         resolved external-tool paths; the Nix build regenerates it
                       with absolute /nix/store paths (dev default = PATH names)
  Ui/
    qmldir             declares module qs.Ui
    BarItem.qml        bar-segment primitive (padded label, hover, signals)
    Panel.qml          summonable-panel base (layer-shell card + dismiss)
    PanelButton.qml    labelled pill control for panel bodies
  Bar/
    qmldir             declares module qs.Bar
    <Widget>.qml       one component per bar segment
  Osd/
    qmldir             declares module qs.Osd
    Osd.qml            volume/brightness/mic-mute overlay (replaces SwayOSD)
  Services/
    qmldir             declares module qs.Services
    PanelManager.qml   singleton tracking the one open panel (mutual exclusion)
    SystemStats.qml    singleton: shared CPU/memory sampler (bar + monitor panel)
    NotificationState.qml  singleton: DND flag + live toast list (shared state)
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
| WorkspacesWidget | `Quickshell.Hyprland` |
| ClockWidget | `Quickshell.SystemClock` |
| TrayWidget | `Quickshell.Services.SystemTray` |
| DictationWidget | `voxtype status --follow` (click = toggle); baked on/off via `Style.dictationIndicator` |
| CaffeineWidget | `pgrep` probe + `marchyo toggle caffeine` |
| DndWidget | in-shell `Services/NotificationState` (click = toggle DND) |
| KeyboardLayoutWidget | `hyprctl devices` (click = cycle layout) |
| BluetoothWidget | `Quickshell.Bluetooth` (click = bluetui) |
| NetworkWidget | `Quickshell.Networking` + `nmcli` for SSID/signal (click = network panel) |
| AudioWidget | `Quickshell.Services.Pipewire` (scroll = volume, right-click = mute, click = audio panel) |
| CpuWidget | `Services/SystemStats` (`/proc/stat`) (click = monitor panel) |
| PowerProfileWidget | `Quickshell.Services.UPower` `PowerProfiles` (click = cycle) |
| BatteryWidget | `Quickshell.Services.UPower` (click = power panel) |

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
current level whenever it changes, replacing SwayOSD. Its triggers are **native
and pull-based** — nothing pokes it:

- **volume / mic mute** — `Quickshell.Services.Pipewire` bindings on the default
  sink/source; a `Connections` on their `audio` object shows the overlay on any
  volume or mute change (guarded so the startup binding storm doesn't flash it).
- **brightness** — the first `/sys/class/backlight/<dev>` node (discovered once
  via the baked `Config.ls`) is watched with a `FileView` (`watchChanges`); a
  change redraws the overlay with `brightness / max_brightness`.

The Hyprland media keys therefore keep doing the *actual* change (silent
`wpctl` / `brightnessctl`, see `modules/home/hyprland.nix`) and the shell draws
the overlay reactively — no `swayosd-client`, no IPC. Enabling the shell stands
SwayOSD down (`modules/home/swayosd.nix`); the backlight udev write-access from
`modules/nixos/osd.nix` still applies, so `brightnessctl` keeps working.

> Live-verify note: sysfs `inotify` delivery for the backlight node must be
> confirmed on a real host. If a brightness key doesn't flash the overlay, the
> fallback is a one-line IPC poke from the bind (`qs ipc call`) — see
> `plans/shell.md`.

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

Each panel reuses the exact native bindings of its bar widget and keeps a button
to the corresponding TUI/menu for anything the panel doesn't cover. Panels
currently render on the default screen (per-output panels are deferred).

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
`toggleDnd()` / `setDnd(on)` / `clearNotifications()`, and `osdShow(...)`.
Hyprland binds (added by `modules/home/hyprland.nix` and
`modules/home/window-toggles.nix` only when the shell is enabled) reach the
running process through the wrapped binary:

```
marchyo-shell ipc -n call -- shell togglePanel monitor
```

The `marchyo-shell` wrapper bakes its own `-p <store-path>`, so the call
self-targets the running instance (no instance id to track). Default binds:
`SUPER+SHIFT+V` audio, `SUPER+SHIFT+N` network, `SUPER+SHIFT+B` power,
`SUPER+SHIFT+M` monitor. The DND toggle (`SUPER+CTRL+comma`) and dismiss-all
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
Per-urgency timeouts mirror mako: low/normal 5s, critical persistent.

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

### Deferred (cosmetic parity, optional)

- **Tray expander/drawer grouping** — the shell shows tray icons inline.
- **Clock `format-alt` toggle** — click-to-switch date/time form.

## Development

Run the tree directly for a fast QML iteration loop (no rebuild):

```bash
quickshell -p shell          # from the repo root
# or, the wrapped, theme-baked package:
nix run .#marchyo-shell
```

The checked-in `Commons/Color.qml` / `Commons/Style.qml` are the Field (dark),
`fontScale 1.0` defaults so the dev loop works standalone; the Nix build
overwrites both for the host's `marchyo.theme.variant` and `fontScale`.

To type-check the QML without a Wayland compositor, point Quickshell at a small
harness that instantiates the widgets outside a `PanelWindow` and run it under
`QT_QPA_PLATFORM=offscreen` — "Configuration Loaded" with no `WARN`/`ERROR` from
your own files means the tree parses and binds cleanly.
