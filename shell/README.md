# shell/ — the marchyo Quickshell shell

A custom [Quickshell](https://quickshell.org) desktop shell: a single
long-running QML process that will eventually replace today's discrete
waybar + mako + swayosd + vicinae composition (bar, panels, OSD,
notifications, lock). Design and roadmap: **[../plans/shell.md](../plans/shell.md)**.

## Status — Phase 1 (bar)

A Jylhis-themed top bar at (near) waybar parity, built as a **simple monolith**:
`shell.qml` composes reusable widgets from `Bar/` (backed by the `Ui/` primitive
and the `Commons/` design-token singletons). No plugin registry or IPC yet — that
architecture lands with the summonable panels of Phase 2.

Gated behind `marchyo.shell.enable` (default off); it **coexists** with the
discrete stack (it does not disable waybar/mako/swayosd), so both bars can run
during development until parity is proven.

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
  Ui/
    qmldir             declares module qs.Ui
    BarItem.qml        the one shared primitive (padded label, hover, signals)
  Bar/
    qmldir             declares module qs.Bar
    <Widget>.qml       one component per bar segment
```

### Widgets

Native Quickshell service bindings (no external tools):

| Widget | Backing service |
| --- | --- |
| SessionWidget | static "marchyo" label |
| WorkspacesWidget | `Quickshell.Hyprland` |
| ClockWidget | `Quickshell.SystemClock` |
| TrayWidget | `Quickshell.Services.SystemTray` |
| AudioWidget | `Quickshell.Services.Pipewire` (scroll = volume, right-click = mute) |
| CpuWidget | `Quickshell.Io.FileView` over `/proc/stat` |
| BluetoothWidget | `Quickshell.Bluetooth` |
| NetworkWidget | `Quickshell.Networking` |
| PowerProfileWidget | `Quickshell.Services.UPower` `PowerProfiles` (click = cycle) |
| BatteryWidget | `Quickshell.Services.UPower` |

### Deferred (still covered by waybar during coexistence)

- **Keyboard-layout, DND, and dictation widgets** — need external tools
  (`hyprctl`, the `marchyo` CLI, `voxtype`) and so depend on the tool-path
  baking below.
- **Click-to-launch-TUI actions** (audio → wiremix, network → nmtui,
  battery → power menu, etc.) — same dependency.
- **Network SSID + signal strength** — the native `Quickshell.Networking` API in
  Quickshell 0.3 exposes neither, so the widget shows `wifi`/`eth`/`offline`
  only; richer parity needs an `nmcli`-backed variant.
- **Tool-path baking** — resolving those external tools hermetically (a generated
  `Config.qml` of `/nix/store` paths passed as package args) rather than relying
  on the session `PATH`.

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
