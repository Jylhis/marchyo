# shell/ — the marchyo Quickshell shell

A custom [Quickshell](https://quickshell.org) desktop shell: a single
long-running QML process that will eventually replace today's discrete
waybar + mako + swayosd + vicinae composition (bar, panels, OSD,
notifications, lock). Design and roadmap: **[../plans/shell.md](../plans/shell.md)**.

## Status — Phase 1 (bar) done, Phase 2 (OSD) in progress

A Jylhis-themed top bar at (near) waybar parity, built as a **simple monolith**:
`shell.qml` composes reusable widgets from `Bar/` (backed by the `Ui/` primitive
and the `Commons/` design-token singletons). Phase 2 adds surfaces **alongside**
the bar as plain in-process components — starting with the **OSD** (`Osd/`).
There is deliberately **no plugin registry or manifest system**: marchyo rejected
the third-party-plugin story (see `plans/shell.md`), so native Quickshell service
bindings plus (where a keybind must reach in) a stock `IpcHandler` suffice.

Gated behind `marchyo.shell.enable` (default off). Enabling it **replaces
waybar** and, now, **SwayOSD** (each mutually exclusive with its discrete
counterpart — see `modules/home/waybar.nix` and `modules/home/swayosd.nix`);
mako stays until the shell reaches its parity in Phase 3.

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
  Osd/
    qmldir             declares module qs.Osd
    Osd.qml            volume/brightness/mic-mute overlay (replaces SwayOSD)
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
