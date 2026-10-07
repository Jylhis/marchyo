# shell/ — the marchyo Quickshell shell

A custom [Quickshell](https://quickshell.org) desktop shell and the default
Marchyo desktop shell: a single long-running QML process for the bar, panels,
OSD, notifications, launcher, lock, and polkit agent. The discrete
waybar + mako + swayosd + vicinae + hyprlock + hyprpolkitagent stack stays as
the `marchyo.shell.enable = false` fallback. Design and roadmap:
**[../TODO.md](../TODO.md)**.

## Status — Phase 1 (bar) + Phase 2 (OSD + panels) + Phase 3 (notifications) + Phase 5 (launcher) done

A Jylhis-themed top bar at (near) waybar parity, built as a **simple monolith**:
`shell.qml` composes reusable widgets from `Bar/` (backed by the `Ui/` primitives
and the `Commons/` design-token singletons). Phases 2 and 3 add surfaces
**alongside** the bar as plain in-process components — the **OSD** (`Osd/`), the
summonable **panels** (`Panels/`, toggled from their bar widgets through the
`Services/` `PanelManager` singleton), and the **notification** toasts
(`Notifications/`, owning `org.freedesktop.Notifications`). Extension is
**build-time, Nix-declared** (the Option A plugin platform): plugins are baked
into the store shell via `pkgs.mkMarchyoShellPlugin` and never discovered at
runtime — there is no runtime plugin directory or hot-reload. Native Quickshell
service bindings plus a stock `IpcHandler` cover everything the shell itself
needs. `shell/compat/` additionally provides an omarchy plugin host API
(`qs.compat.Ui` / `qs.compat.Commons`) so upstream omarchy bar widgets run
near-unmodified; see the "Plugins" docs.

A hardening pass added **tooltips** (one shared hover surface under the bar),
**SNI tray menus** on right-click, **per-monitor workspaces** with waybar's
persistent 1–5, the full **battery state set** (charging / full / plugged-in),
shared `Services/` singletons for audio/power/network (one binding each for
bar, panel, and OSD), an **event-driven keyboard-layout widget** (no poll),
toast transitions, a DND queue cap, and a committed offscreen **type-check
harness** (`just -f shell/Justfile check`).

A second pass (see the references in **[../TODO.md](../TODO.md)**,
a survey of ten public Hyprland/Quickshell projects) moved the last three
stateful widgets into `Services/` singletons: `shell.qml` builds the bar once per
screen, so a `Process` or `Timer` inside a widget was one subprocess **per
monitor** answering a seat-global question. `Bar/` widgets are now pure views,
the `voxtype --follow` stream **restarts with backoff** when it ends, and the
shell grew two **headless test suites** that `nix flake check` runs (see
[Tests](#tests)).

Gated behind `marchyo.shell.enable`, which defaults to on with
`marchyo.desktop.enable` (cascaded in `modules/nixos/desktop-config.nix`). The
shell **replaces waybar**, **SwayOSD**, **mako**, **hyprlock** (Phase 4),
**vicinae** (Phase 5), and **hyprpolkitagent**, each mutually exclusive with its
discrete counterpart (see `modules/home/waybar.nix`, `modules/home/swayosd.nix`,
`modules/home/mako.nix`, `modules/home/hyprlock.nix`,
`modules/home/vicinae.nix`, and `modules/home/hyprland.nix`), so the shell owns
the bar, the OSD, notifications, the lock, the launcher, and the polkit agent
outright. Setting `marchyo.shell.enable = false` keeps the discrete stack.

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
    ShellConfig.qml    singleton reading ~/.config/marchyo/shell.json (the live
                       marchyo.shell.* config, materialized by the Nix build);
                       barFor(output) gives a bar its per-monitor layout
    MonitorConfig.js   pure per-monitor resolution of shell.json (global config
                       + monitors.<output> override, always-global keys kept)
    PluginIndex.qml    singleton listing the plugins baked into this store shell
                       (build-time Option A model; no runtime discovery), see
                       Plugins below
    Format.js          pure parsing helpers (keymap short codes, nmcli device show);
                       plain JS with a CommonJS guard so Node can unit-test it
    Match.js           pure fuzzy scoring + highlight markup over fuzzysort
                       (launcher providers)
    fuzzysort.js       vendored fuzzysort 3.1.0 (MIT; pinned, see its header)
    Fuzzy.qml          singleton binding Match.js to fuzzysort.js for QML
    LauncherProviders.js  pure launcher prefix routing, ranking, and the
                       theme / hyprctl clients / qalc output parsers
    EmojiData.js       emoji catalog rows + parse; the Nix build regenerates the
                       rows from pkgs.unicode-emoji (dev subset checked in)
    Cliphist.js        pure cliphist helpers (quoted-printable payload decode,
                       image-entry preview parsing + cache names)
    Notify.js          pure notification match/eviction helpers
    Overview.js        pure window-overview helpers (grouping by workspace,
                       search filter, keyboard navigation, tile layout math)
    BarLayout.js       pure bar-separator decisions (cluster-aware rules)
    Peripherals.js     pure `solaar show` parser (Logitech battery)
  Ui/
    qmldir             declares module qs.Ui
    BarItem.qml        bar-segment primitive (padded label, hover, signals, tooltip)
    BarSection.qml     one anchored bar group; collapsing slots + cluster-aware rules
    BarSeparator.qml   thin vertical rule between bar clusters
    BarSegment.qml     one segmented-style cluster background (QtQuick.Shapes)
    Panel.qml          summonable-panel base (layer-shell card + dismiss)
    PanelButton.qml    labelled pill control for panel bodies
    PanelSlider.qml    0..1 slider for panel bodies (Control Center volume/mic)
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
  Polkit/
    qmldir             declares module qs.Polkit
    PolkitDialog.qml   centered polkit password dialog (replaces hyprpolkitagent)
  Launcher/
    qmldir             declares module qs.Launcher
    LauncherWindow.qml the launcher overlay (exclusive keyboard focus layer)
    ResultsView.qml    renders the active provider's results (list or grid)
    Provider.qml       the provider interface every provider below implements
    AppsProvider.qml   app search over DesktopEntries (replaces vicinae apps)
    EmojiProvider.qml  emoji grid over Commons/EmojiData.js
    ClipboardProvider.qml  cliphist history list + paste, image thumbnails
    CalcProvider.qml   "=" calculator over qalc
    ThemeProvider.qml  ">theme" switcher over `marchyo theme list|set`
    WindowsProvider.qml  "#" window switcher over `hyprctl clients -j`
    PowerProvider.qml  "!" session actions (lock / log out / power verbs)
  Services/
    qmldir             declares module qs.Services
    PanelManager.qml   singleton tracking the one open panel (mutual exclusion)
    SystemStats.qml    singleton: shared CPU/memory sampler (bar + monitor panel)
    NotificationState.qml  singleton: DND flag + live toast list (shared state)
    Audio.qml          singleton: shared Pipewire default sink/source + tracker
    Power.qml          singleton: shared UPower battery state + waybar-parity text
    NetworkStatus.qml  singleton: active device, SSID/signal, Wi-Fi radio switch
                       (native Networking) + event-driven nmcli IPv4 probe
    BluetoothState.qml singleton: default BlueZ adapter, power, connected devices
    PowerProfileState.qml  singleton: power-profiles-daemon profile + cycle
    QuickToggles.qml   singleton: the Control Center toggle model (no presentation)
    Dictation.qml      singleton: the one voxtype --follow stream (with restart)
    Caffeine.qml       singleton: the one keep-awake probe + toggle, plus the auto video inhibit
    KeyboardLayout.qml singleton: the one hyprctl probe + activelayout listener
    LockKeys.qml       singleton: Caps/Num Lock from the keyboard LEDs (polled while shown)
    Camera.qml         singleton: camera-in-use apps (PipeWire links + /dev/video* holders)
    Tooltip.qml        singleton: hovered item text/position (drives TooltipWindow)
    Lock.qml           singleton: lock state + the PAM auth machine (Phase 4)
    Polkit.qml         singleton: the session's PolkitAgent + dialog state
    Launcher.qml       singleton: launcher mode, query + prefix routing, paste helper
    Overview.qml       singleton: window overview open flag, query, selection + model
  Panels/
    qmldir             declares module qs.Panels
    <Name>Panel.qml    one summonable panel (audio / network / power / monitor)
    ControlCenter.qml  quick-settings panel (sliders + toggle tiles)
  Notifications/
    qmldir             declares module qs.Notifications
    NotificationDaemon.qml  owns org.freedesktop.Notifications (replaces mako)
    NotificationList.qml    top-right layer-shell toast stack
    NotificationPopup.qml   one themed toast card (delegate)
  Overview/
    qmldir             declares module qs.Overview
    OverviewLayer.qml  one OverviewWindow per screen
    OverviewWindow.qml full-screen overlay: search field + workspace grid
    WorkspaceTile.qml  one workspace, its windows at their scaled positions
    WindowPreview.qml  one window: live ScreencopyView + title
```

The shell also declares a single stock `Quickshell.Io.IpcHandler` (target
`shell`) in `shell.qml` so Hyprland keybinds can summon panels and poke the OSD;
see [Keybind summons](#keybind-summons) below.

### Shape and materiality

The bar is a **floating pill** by default: detached from the screen edges
(`Style.barMarginH/V`), rounded (`Style.barRadius`), translucent
(`Style.surfaceAlpha`), and floating over content (no layout reservation).
`marchyo.theme.appearance.floatingBar = false` restores the full-width strip
(all three bake to 0), and `surfaceAlpha = 1.0` restores opaque surfaces.
With alpha below 1 the home Hyprland config enables its blur effect and
registers blur layer rules for the shell's `marchyo:*` layer-shell
namespaces (bar, panels, toasts, OSD, launcher, overview, tooltip) — the glass look —
while a `no_blur` window rule keeps app windows unblurred.

Every surface sets `WlrLayershell.namespace` to `marchyo:<surface>`; that
prefix is the blur anchor and stays stable across surfaces.

`marchyo.shell.settings.bar.style` picks the bar look, read live from
shell.json through `ShellConfig.barStyleFor(<output>)` (so
`monitors.<output>.bar.style` overrides it per output):

- `flat` (default): widgets sit straight on the pill.
- `segmented`: `Ui/BarSection` fills each cluster (the visible widgets between
  two rendered separators, or a whole section without separators) with a
  `Ui/BarSegment` background. Tones alternate within a section between
  `Color.bgSubtle` and `Color.surface` tinted with 18% `Color.accent` (both
  at `Style.surfaceAlpha`), so a theme swap recolours them. `Ui/BarItem`
  finds its section through the parent chain and hovers in a 36% accent tint
  of `Color.surface` there, distinct from both tones (flat keeps
  `Color.surface`). Outer ends are rounded with `Style.barRadius`; adjacent
  segments meet in a circular-arc join centred on the separator, convex on the
  earlier segment and concave on the later one. The join depth is the
  separator plus the smaller padding of its two neighbours, so the curve stays
  inside the padding. The separator rule turns transparent and keeps its
  width. The shapes are `QtQuick.Shapes` paths (`Shape.CurveRenderer`, no
  images) on a zero-width layer behind the slots, so widths, positions, and
  paddings match the flat style exactly; the harness asserts it.

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
| CaffeineWidget | `Services/Caffeine` → `pgrep` probe + `marchyo toggle caffeine`; lit while a video plays (tooltip `auto: <player>`) |
| ThemeWidget | Commons/Theme → colors.json behind the current-theme pointer (click = marchyo theme next) |
| DndWidget | in-shell `Services/NotificationState` (click = toggle DND) |
| KeyboardLayoutWidget | `Services/KeyboardLayout` → `hyprctl devices` probe + `Hyprland` `activelayout` raw events (no poll) |
| LockKeysWidget | `Services/LockKeys` → `/sys/class/leds/*::capslock` / `*::numlock` brightness, a 500 ms read poll while placed (shows `CAPS` / `NUM`; registered as `marchyo.lockKeys`, not placed by default) |
| BluetoothWidget | `Services/BluetoothState` → `Quickshell.Bluetooth` (click = bluetui) |
| NetworkWidget | `Quickshell.Networking` via `Services/NetworkStatus` (click = network panel) |
| CameraWidget | `Services/Camera` → `Quickshell.Services.Pipewire` links out of `Video/Source` nodes + a `find` scan of `/proc/*/fd` for `/dev/video*` (3 s, only while PipeWire reports a camera); shown only while a camera is in use, tooltip names the apps |
| AudioWidget | `Services/Audio` → `Quickshell.Services.Pipewire` (scroll = volume, right-click = mute, click = audio panel) |
| CpuWidget | `Services/SystemStats` (`/proc/stat`) (click = monitor panel) |
| PowerProfileWidget | `Services/PowerProfileState` → `Quickshell.Services.UPower` `PowerProfiles` (click = cycle) |
| BatteryWidget | `Services/Power` → `Quickshell.Services.UPower` (click = power panel) |
| ControlCenterWidget | `Services/PanelManager` (click = Control Center; `marchyo.controlCenter`, last in the default right group) |

Caffeine has two independent sources. The manual toggle (`marchyo toggle
caffeine`) stops hypridle and holds a tagged sleep:idle inhibitor. The automatic
one holds `systemd-inhibit --what=idle --why=marchyo-video-inhibit` while any
MPRIS player that looks like video is Playing (identity, desktop entry or bus
name is mpv/VLC/Celluloid/Totem/a browser, or `xesam:url` has a video
extension; browsers playing audio also match), and releases it on pause or
stop. hypridle honours logind idle inhibitors, so it stays the idle authority.
Auto never touches the manual inhibitor, and a click always flips the manual
one. Disable auto with `marchyo.shell.settings.caffeine.autoVideo = false`.

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
  brightness binds (see `modules/home/hyprland.nix`) run `marchyo brightness
  up|down`, which runs `brightnessctl` and then calls `osdShow BRT <pct> true`
  over the shell IPC with the resulting level. This is deliberate: sysfs attribute writes signal
  `POLLPRI`, which `FileView`'s watcher (inotify) does not see on most hosts.
  A native `FileView` (`watchChanges`) on the first `/sys/class/backlight`
  node remains as a best-effort fallback for brightness changes made outside
  the keybinds (other tools, external monitors' DDC).

The Hyprland media keys therefore keep doing the *actual* change (`marchyo
volume` / `marchyo brightness`: silent `wpctl` / `brightnessctl` + the poke
for brightness; see `modules/home/hyprland.nix`). Enabling the shell stands SwayOSD down
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
| AudioPanel | AudioWidget | `Pipewire` | volume -/+, mute, output-device picker, per-app volume + peak meters, `wiremix` escape |
| NetworkPanel | NetworkWidget | `Networking` + `nmcli` (IPv4 only) | connection status, SSID/signal, IPv4, Wi-Fi radio switch, `nmtui` escape |
| PowerPanel | BatteryWidget | `UPower` + `PowerProfiles` | battery detail, profile selector, `power menu` escape |
| MonitorPanel | CpuWidget | `Services/SystemStats` + `df` + hwmon | CPU / mem / disk / temp meters, `btop` escape |
| ControlCenter | ControlCenterWidget | `Services/QuickToggles` + `Audio` | volume / mic sliders, live mic level, quick-toggle tiles (see below) |

`Services/NetworkStatus` reads the active device, its interface name, the
connected Wi-Fi network (SSID and signal) and the radio switches from
`Quickshell.Networking`, with no polling. Quickshell 0.3.1's Networking API
has no IP configuration, so the IPv4 address shown in the tooltip and panel
comes from one `nmcli -t device show <ifname>` that runs only when the active
device, its connection state, or the connected network changes. A DHCP lease
that changes the address without a reconnect shows on the next such change.

Per-app output routing persists across restarts through WirePlumber. Its
`node.stream.restore-target` setting (default on; marchyo does not change it)
saves a stream's target whenever `target.object` / `target.node` is set on the
`default` metadata and restores it the next time that app's stream appears.
That is the path `wiremix`, `pavucontrol`, and pulse `move-sink-input` take,
and the state lives in `~/.local/state/wireplumber/stream-properties`. The
AudioPanel's device picker sets the default sink
(`Pipewire.preferredDefaultAudioSink`), which WirePlumber also persists.

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

### Control Center

`Panels/ControlCenter.qml` (`panelId: "controlcenter"`) is the quick-settings
card: output-volume and microphone sliders (`Ui/PanelSlider`) with mute buttons
over `Services/Audio`, a live mic input meter (a `PwNodePeakMonitor` on the
default source, enabled only while the card is open and the mic is unmuted),
and a two-column tile grid over the
`Services/QuickToggles` model. It opens from the `marchyo.controlCenter` bar
widget (the last entry of the default right group), `marchyo shell toggle
controlcenter`, or `SUPER+SHIFT+Q`.

`QuickToggles` holds no presentation: each entry exposes `key`, `icon`, `label`,
`status`, `active`, `available`, `detail` (a panelId or `""`) and `toggle()`,
bound to the owning service. `all` is a fixed array, so the tile Repeater never
resets; unavailable entries render no tile.

| Tile | State and action | Available when | Detail |
| --- | --- | --- | --- |
| Wi-Fi | `NetworkStatus.wifiEnabled` / `setWifiEnabled` (NetworkManager radio via `Quickshell.Networking`) | a Wi-Fi device exists | network |
| Bluetooth | `BluetoothState.enabled` / `toggle` (BlueZ adapter power) | a default adapter exists | none |
| Tailscale | `Tailscale.running` / `setUp` (`tailscale up --timeout=20s` / `down`) | the CLI is baked (`marchyo.services.tailscale.enable`) and answers | tailscale |
| Do not disturb | `NotificationState.dnd` / `toggleDnd` | always | notifications |
| Caffeine | `Caffeine.active` / `toggle` | always | none |
| Night light | `Nightlight.enabled` / `toggle` | always | none |
| Power profile | `PowerProfileState.profile` (on = not balanced) / `cycle` | always | power |

A tile click flips its toggle; the chevron opens the detail panel through
`PanelManager.openDetail(id, "controlcenter")`, and `Ui/Panel` shows a back
button while `PanelManager.returnId` is set. tailscaled accepts up/down only
from root or the tailnet operator. With the shell on, NixOS sets the operator to
the first enabled marchyo user (`marchyo.services.tailscale.operator`, applied
by the `tailscaled-set` unit); a refusal shows as the tile status and in full in
the Tailscale panel.

### Keybind summons

`shell.qml` declares one stock `IpcHandler { target: "shell" }` exposing
`togglePanel(id)` / `openPanel(id)` / `closePanel(id)` / `closePanels()`, the
notification controls `toggleDnd()` / `setDnd(on)` / `clearNotifications()`,
the read-only queries `barState()` / `dndState()` (feeding `marchyo toggle
waybar|notifications --status`), and `osdShow(...)` — the last is the
brightness OSD's **primary trigger** (the
brightness binds poke it after every `brightnessctl` change; see the OSD
section), plus `ping()` and `reload()`. The `marchyo shell` CLI verbs wrap it (`toggle|open <panel>`,
`close [<panel>]`, `launcher <mode>`, `bar [on|off]`, `lock`, `lock-state`,
`bar-state`, `dnd-state`,
`dismiss [--all]`, `dnd [on|off]`, `overview [on|off]`, `reload`), and the Hyprland binds in
`modules/home/hyprland.nix` and `window-toggles.nix`, hypridle, and the
screensaver (all added only when the shell is enabled) run those verbs, by
store path when `marchyo.cli.enable` is off. Under the hood every call goes
through the wrapped binary:

```
marchyo-shell ipc -n call -- shell togglePanel monitor
```

The `marchyo-shell` wrapper bakes its own `-p <store-path>`, so the call
self-targets the running instance (no instance id to track). Default binds:
`SUPER+SHIFT+V` audio, `SUPER+SHIFT+N` network, `SUPER+SHIFT+B` power,
`SUPER+SHIFT+M` monitor, `SUPER+SHIFT+Q` Control Center; the launcher summons (`toggleLauncher apps|emoji|
clipboard`) ride `SUPER+R` / `SUPER+period` / `SUPER+CTRL+V`, and
`SUPER+grave` runs `marchyo shell overview` (`toggleOverview()`). The DND toggle
(`SUPER+CTRL+comma`) and dismiss-all
(`SUPER+CTRL+SHIFT+comma`) binds run `marchyo shell dnd` / `marchyo shell
dismiss --all` and `SUPER+N` runs `marchyo shell toggle notifications` when the
shell is on; the first two fall back to the CLI/mako when it is off. This is the
only IPC in the shell; there is no custom bus.

### Overview

`Overview/` is the window overview (expose): a full-screen `marchyo:overview`
layer on every screen showing each regular workspace as a scaled-down tile of
its monitor, with every window at its real position as a live
`ScreencopyView` of its Hyprland toplevel. `Services/Overview` holds the open
flag, the query and the selected window, and builds the model from
`Quickshell.Hyprland`'s toplevels, workspaces and monitors (refreshed on open
and on window/workspace events while open). The model is empty and the
overlay content unloaded while closed, so previews and capture exist only
while the overview is shown. The pure logic lives in `Commons/Overview.js`.

- The search field filters windows by title and class through the launcher's
  `Commons/Fuzzy` matcher; non-matching windows hide and workspaces without a
  match dim. A fresh query selects the best match; an empty one selects the
  focused window.
- Keys: `Tab` / `Shift+Tab` (and `Left` / `Right` while the query is empty)
  step through the matching windows, `Up` / `Down` move one grid row, `Enter`
  focuses the selection (`focuswindow`, switching workspace), `Escape` closes.
- Mouse: hover selects, a click focuses the window, a click on a tile's empty
  area switches to that workspace, a click outside the tiles closes.
- Only the focused output's overlay takes keyboard focus; the others mirror
  the shared query and selection. Opening the overview closes the launcher and
  any open panel.

Summoned by `SUPER+grave` / `marchyo shell overview [on|off]`
(`toggleOverview()` / `openOverview()` / `closeOverview()`).

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

- `SUPER+L` runs `marchyo shell lock`; hypridle's lock points (`lock_cmd`,
  `before_sleep_cmd`, the 300s listener in `modules/home/hypridle.nix`) run
  `marchyo shell lock` too. hypridle stays the single idle
  authority so `marchyo toggle idle` keeps disabling idle lock; Quickshell's
  `IdleMonitor` is deliberately unused (no second idle watcher, no
  double-lock race).
- The idle screensaver asks `marchyo shell lock-state` before launching — the same
  guard it had for a running hyprlock.

Each screen gets one `WlSessionLockSurface` (clock on every output); the
focused output additionally renders the password card and the PAM messages
(focus follows the seat's focused monitor at lock time; clicking another
output moves the card there). The session is locked on ALL outputs either way —
ext-session-lock-v1 demands a surface per output. Focus and `pam.start()` are
gated on `secure` (compositor-confirmed coverage), per the upstream docs.

Every surface absorbs all input: a full-surface `MouseArea` (all buttons,
hover, wheel) plus a `PinchHandler`, and a focused backdrop whose
`Keys.onPressed` swallows every key the field does not consume. A press or
keystroke on an output without the card moves the card there (forwarding the
first printable character), and the field reclaims focus whenever it loses it
on the card's output. The field goes `readOnly` (not disabled) while PAM is
busy, so it keeps focus.

A rejected password (`PamResult.Failed` / `MaxTries`) clears the field, shakes
it (a `Translate` driven by an explicit animation that settles at 0, no
`Behavior`), and holds a failure state for 3s: `Services/Lock` owns the
`failed` flag, its reset `Timer`, and a `failureCount` that re-arms the shake
on back-to-back failures. While `failed`, the failure line shows over the fresh
PAM prompt and the field border is `Color.statusErr`.

> **Testing warning:** destroying the shell (crash, or a hot-reload from the
> dev loop) while locked leaves a conformant compositor showing a solid
> color — by design. Never edit QML while a dev instance is locked, and keep
> a TTY logged in when live-testing.

### Polkit agent

`Services/Polkit.qml` holds the session's polkit authentication agent
(`Quickshell.Services.Polkit.PolkitAgent`); `Polkit/PolkitDialog.qml` draws its
prompt. With the shell on, `modules/home/hyprland.nix` turns
hyprpolkitagent off (a session holds one registered agent); with the shell off
hyprpolkitagent stays the agent. A request (e.g. `pkexec`, a systemd unit
action, a 1Password unlock) shows a scrim plus a centered card on the focused
output, layer namespace `marchyo:polkit`, with exclusive keyboard focus: the
action message, the identity it authenticates as, the action id, PAM's
supplementary line, and a password field. Enter or Authenticate submits;
Escape or Cancel cancels the request. An outside click is absorbed and does
not cancel. A rejected password clears the field, shakes the card, and shows
the failure line while Quickshell starts a fresh PAM session for the retry.
Queued requests show one after another. If another agent already holds the
session (a dev instance next to the store shell), `Polkit.registered` stays
false and no dialog appears.

### Launcher

`Launcher/LauncherWindow.qml` is the Phase 5 launcher, a command palette: a
full-screen transparent overlay (the Ui/Panel dismiss idiom) with a centered
card, one shared query field, and one result list, replacing vicinae under
the same mutual-exclusion cutover as waybar/mako/SwayOSD/hyprlock.
`Services/Launcher` holds the open mode ("" / "apps" / "emoji" /
"clipboard") and the query, and routes them to a provider; the surface takes
`WlrKeyboardFocus.Exclusive` while open and closes on Escape, outside click,
or focus loss.

Every source of rows is a provider (`Launcher/Provider.qml`): it turns its
`query` into `results`, rows of `title`, `subtitle`, `icon`, `score`,
`positions` (title highlight) and `activate()`, and declares how
`Launcher/ResultsView.qml` presents them (list or grid, icons, row count).
A provider only receives a query, and only runs its subprocesses, while it is
the active one. Up/Down move the selection (by three cells in the emoji
grid, where Left/Right move by one), Enter activates.

| Mode | Bind | Backing | Activate |
| --- | --- | --- | --- |
| apps | `SUPER+R` | `Quickshell.DesktopEntries` (webapps' `xdg.desktopEntries` flow in) | `DesktopEntry.execute()` — results list (8 rows, app icons via `IconImage` with an `application-x-executable` fallback), inline ghost-text completion on Tab/Right |
| emoji | `SUPER+period` | `Commons/EmojiData.js` — rows generated from `pkgs.unicode-emoji`'s emoji-test.txt at package build (dev subset checked in; fully-qualified entries, Component group dropped) | copy + type |
| clipboard | `SUPER+CTRL+V` | one `cliphist list` per open (fed by the wl-paste watchers in `modules/home/hyprland.nix`); payloads decode in `Commons/Cliphist.js`; image entries get a thumbnail row (see below) | text: copy + type; image: `wl-copy` + Ctrl+V |

Paste (emoji/clipboard) goes through `Services/Launcher.pasteText`:
`Quickshell.clipboardText` for the copy, then `wtype` after a 0.25 s settle
— the launcher closes first so wtype delivers to the previously focused
window. No privileged helper: vicinae's `cap_dac_override` uinput wrapper
stands down with the cutover (gated in `modules/nixos/launcher.nix`). The
text travels as argv (`exec "$0" "$1"`), never through shell interpolation.

Clipboard image entries (cliphist lists them as `[[ binary data 12 KiB png
800x600 ]]`) become rows titled `png 800x600 · 12 KiB`, searchable like text;
other binary entries are skipped. The provider sets `previews`, so
`ResultsView` draws those rows three rows tall with a thumbnail and calls the
provider's `requestPreview` when a row's delegate is created, which limits
decoding to rows in view. Decodes run one at a time as `cliphist decode <id>`
into the shell's own cache, `<Quickshell.cacheDir>/cliphist/`, under the
`Cliphist.cacheName` key (id, dimensions and size, so an id reused after
`cliphist wipe` misses). Each decode writes a `.part` file and renames it,
skips entries listed above 16 MiB, cuts output at that bound, and prunes the
directory to the 48 most recently shown files. Every value travels as argv.
Activating an image row runs `Services/Launcher.pasteImage`: `cliphist
decode | wl-copy --type image/<format>` (`Config.wlCopy`), then Ctrl+V via
`wtype` after the same settle.

In apps mode a prefix routes the query to another provider; the rest of the
text is that provider's query. The emoji and clipboard modes search the whole
text, prefix characters included.

| Prefix | Provider | Backing | Activate |
| --- | --- | --- | --- |
| `=` | calc | `qalc -t -- <expr>` (`Config.qalc`, libqalculate: units, conversions, currencies); one evaluation at a time, the latest expression queued | copy the answer |
| `>theme` | theme | `marchyo theme list --format json`, once per activation | `marchyo theme set <name>` (live switch) |
| `#` | windows | `hyprctl clients -j`, once per activation (most recently focused first; title and class searched) | focus the window (`focuswindow address:`) |
| `!` | power | lock, log out, suspend, hibernate, reboot, shut down | `marchyo <verb>`; lock goes to the shell's own lock (`Services/Lock`) |

The prefix table and routing live in `Commons/LauncherProviders.js`, beside
the shared ranking and the output parsers, all unit-tested from Node.

Search scoring is `Commons/Match.js` over the vendored fuzzysort
(`Commons/fuzzysort.js`, 3.1.0, the last release with a classic-script
build; its header records the tarball hash and the local changes). QML
reaches it through the `Commons/Fuzzy` singleton, which binds the two files
(a `.import` directive would break Node). Scores map onto 1..2000 with 0 for
an empty query (name order); a space in the query matches words in any
order. `highlight` builds the StyledText markup for the matched characters.

### Plugins

Plugins are built with `pkgs.mkMarchyoShellPlugin`
(`packages/marchyo-shell/plugin.nix`) and baked into the store shell under
`plugins/<id>/`. `Commons/PluginIndex.qml` lists them; package.nix fills in its
one `plugins` line, so the dev tree and the store shell share every function.
Kinds are a closed set (`packages/marchyo-shell/plugin-kinds.nix`), and
`entryPoints` carries exactly one key per declared kind:

| Kind | Entry point | Root type | Loaded by |
| --- | --- | --- | --- |
| `bar-widget` | `barWidget` | a bar item | `shell.qml` `componentFor()`, placed by manifest id in `bar.layout` |
| `launcher` | `launcher` | a `qs.Launcher` `Provider` | `Launcher/LauncherWindow`, selected in apps mode by the manifest `prefix` |
| `daemon` | `daemon` | a non-visual `Item` or `QtObject` | `shell.qml`, one instance at the shell root |

The build checks that the manifest's `kinds`, `entryPoints` and `prefix` equal
the declared arguments. A launcher plugin's `prefix` is required, non-empty,
free of whitespace, and must not start with `=`, `>`, `#` or `!` (the
first-party prefixes); plugin ids and prefixes are unique across the shell.
The launcher sets a plugin provider's `providerId` to the plugin id and its
`prefix` from the manifest, and `Commons/LauncherProviders.js` `route()`
checks first-party prefixes before plugin ones (longest plugin prefix wins). A
launcher or daemon plugin whose QML fails to load is logged with
`console.warn` and skipped. `tests/eval/fixtures/` holds one example plugin
per kind.

Every build writes `share/marchyo/shell/plugins.lock.json`, an empty list
when no plugins are declared:

```json
{
  "lockVersion": 1,
  "plugins": [
    {
      "id": "example.echo",
      "name": "Echo",
      "version": "1.0.0",
      "kinds": ["launcher"],
      "entryPoints": { "launcher": "Provider.qml" },
      "prefix": "?",
      "storePath": "/nix/store/...-marchyo-shell-plugin-example-echo-1.0.0",
      "source": { "url": "https://example.com/echo.git", "rev": "..." }
    }
  ]
}
```

`source` is set for `marchyo.shell.extraPlugins` entries (the CLI-managed
pins) and `null` for flake-declared plugins, whose pin lives in the flake.

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
`CPU 45%`, SSID/signal, …) lives in each widget's hover tooltip. The default
right group is organized into clusters separated by the `marchyo.separator`
widget (a thin `Ui/BarSeparator` rule): alerts · tray + media · toggles ·
connectivity/audio · system · control center. Glyph-only widgets (dictation,
caffeine, theme, dnd, bluetooth, camera, mic, power-profile, night-light,
screen-recording, control center, the tray expander) set `BarItem.compact` for
half horizontal padding so single icons don't render as wide capsules next to
text widgets. The active-window title
elides (`BarItem.elide`) against a layout cap of a quarter of the output width,
so a very long title can never reach the centered clock.

Conditional widgets (media with no player, idle mic, desktop battery, empty
reminders, ...) hide with `visible: false`, and the bar collapses with them:
`Ui/BarSection` binds each slot Loader's visibility to its widget's, so a
hidden widget leaves no gap (a visible Loader around a hidden item would keep
its cell). Separators render only between two clusters that both have visible
content — the rules around an empty cluster collapse to one — decided by the
pure, node-tested `Commons/BarLayout.js` (`tests/shell/bar-layout-test.js`).

Each per-screen bar reads its layout from `ShellConfig.barFor(<output>)`: the
global `bar.layout` with that output's `monitors.<output>` override from
shell.json merged over it (`Commons/MonitorConfig.js`, node-tested by
`tests/shell/monitor-config-test.js`). Objects merge key by key, lists replace
whole, and the always-global keys (`idle`, `caffeine`, `monitors`) ignore
per-monitor values. The overrides live in the same generated shell.json, so
they ride its existing watch.

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
- `QT_QPA_PLATFORMTHEME=gtk3` — the same value the session gets from
  `modules/home/qt.nix` (Qt follows the live GTK surface), pinned for the
  shell process so a host overriding the session (e.g. back to `qt5ct`,
  which has no Qt6 plugin) can't break themed icon resolution; the `gtk3`
  platform theme reads marchyo's own GTK settings (`Adwaita`).

### Tests

Three layers, split by what each can reach:

| Suite | Runs where | Covers |
| --- | --- | --- |
| `tests/shell/format-test.js` | `nix flake check`, or `node tests/shell/format-test.js` | `Commons/Format.js` — the shell's pure parsing (keymap short codes, `nmcli -t device show` records) |
| `tests/shell/notify-test.js` | `nix flake check`, or `node tests/shell/notify-test.js` | `Commons/Notify.js` — notification match/eviction decisions |
| `tests/shell/launcher-test.js` | `nix flake check`, or `node tests/shell/launcher-test.js` | the launcher's pure JS: the vendored fuzzysort pin and license header, `Match.js` scoring over it, `LauncherProviders.js` prefix routing, ranking and the theme / `hyprctl clients` / `qalc` parsers, `EmojiData.js` parsing, `Cliphist.js` quoted-printable/UTF-8 decoding and image-entry parsing / cache names |
| `tests/shell/peripherals-test.js` | `nix flake check`, or `node tests/shell/peripherals-test.js` | `Commons/Peripherals.js` — the `solaar show` parser |
| `tests/shell/monitor-config-test.js` | `nix flake check`, or `node tests/shell/monitor-config-test.js` | `Commons/MonitorConfig.js`: per-monitor shell.json merge, always-global keys, per-section bar fallback |
| `tests/shell/contracts-test.sh` | `nix flake check`, or `bash tests/shell/contracts-test.sh` | static cross-file agreements: qmldir completeness, `Bar/` widgets owning no runtime state, `Services/` all being singletons, the `Config.<tool>` → `package.nix` chain, and every CLI `shellIpc("<fn>")` call resolving |
| `just -f shell/Justfile check` | a machine with Quickshell | the tree actually parses, binds and loads |

The JS suites are the reason `Commons/*.js` files are plain `.js` modules with a
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
