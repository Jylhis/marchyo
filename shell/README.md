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

Gated behind `marchyo.shell.enable` (default off). Enabling it **replaces
waybar** (the two bars are mutually exclusive — see `modules/home/waybar.nix`);
mako/swayosd stay until the shell reaches their parity in Phases 2–3.

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
    BarItem.qml        the one shared primitive (padded label, hover, signals)
  Bar/
    qmldir             declares module qs.Bar
    <Widget>.qml       one component per bar segment
```

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
| DndWidget | `makoctl mode` probe + `marchyo toggle notifications` |
| KeyboardLayoutWidget | `hyprctl devices` (click = cycle layout) |
| BluetoothWidget | `Quickshell.Bluetooth` (click = bluetui) |
| NetworkWidget | `Quickshell.Networking` + `nmcli` for SSID/signal (click = nmtui) |
| AudioWidget | `Quickshell.Services.Pipewire` (scroll = volume, right-click = mute, click = wiremix) |
| CpuWidget | `Quickshell.Io.FileView` over `/proc/stat` (click = btop) |
| PowerProfileWidget | `Quickshell.Services.UPower` `PowerProfiles` (click = cycle) |
| BatteryWidget | `Quickshell.Services.UPower` (click = power menu / launcher) |

TUI launches use `ghostty --class=org.omarchy.* -e <tool>` so Hyprland's existing
float rule applies — the same classes and commands as `modules/home/waybar.nix`.

### Tool-path baking

`Commons/Config.qml` is a generated singleton of resolved binary paths
(`packages/marchyo-shell/package.nix`, same idiom as `Color.qml`/`Style.qml`). The
tool packages arrive as `callPackage` args; `lib.getExe` resolves them. The
checked-in `Config.qml` holds bare `PATH` names so `quickshell -p shell` still runs
standalone; the build overwrites it.

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
