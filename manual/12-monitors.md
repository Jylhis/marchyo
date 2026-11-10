---
title: Monitors
description: Multi-monitor setup, scaling, and runtime display controls.
---

Out of the box you don't need to tell Marchyo anything about your screens. Every
connected monitor is detected and shown at its preferred resolution, placed
automatically, at scale 1, with variable refresh rate on. That covers a single laptop or a desk with one external
display. When you want a fixed arrangement, HiDPI scaling, or a rotated screen, you
describe the layout in your configuration. For quick, one-off changes there are live
tools that don't need a rebuild.

## Describing your layout

Your monitor layout lives in `marchyo.monitors`, one entry per output. Start by
finding the names Hyprland uses for your outputs:

```bash
hyprctl monitors
```

Names look like `eDP-1` (a laptop panel), `DP-1`, or `HDMI-A-1`. Then list the
outputs you care about:

```nix
marchyo.monitors = [
  {
    output = "eDP-1";
    mode = "2256x1504@60";
    position = "0x0";
    scale = 1.5;
  }
  {
    output = "DP-1";
    mode = "3840x2160@144";
    position = "auto-right";
    scale = 2.0;
  }
];
```

Rebuild, and the layout applies every time you log in. Each entry takes:

| Field | Default | What it does |
|-------|---------|--------------|
| `output` | (required) | The output name from `hyprctl monitors` |
| `mode` | `"preferred"` | Resolution and refresh rate as `WIDTHxHEIGHT@HZ`, or `preferred`, `highres`, `highrr` |
| `position` | `"auto"` | Top-left corner as `XxY` (e.g. `"1920x0"`), or `auto`, `auto-right`, `auto-left`, `auto-up`, `auto-down` |
| `scale` | `1.0` | Scale factor; 1.5 or 2.0 suit HiDPI panels |
| `transform` | `0` | Rotation: 1 is 90°, 2 is 180°, 3 is 270°, 4 to 7 are the flipped versions |
| `vrr` | unset | Variable refresh rate: 0 off, 1 on, 2 fullscreen only, 3 fullscreen with video |
| `enable` | `true` | Set `false` to switch the output off entirely |
| `extraSettings` | `{ }` | Extra Hyprland monitor keys, such as `bitdepth` or `mirror` |

Once you set `marchyo.monitors`, your list replaces the automatic rule. To keep
screens you haven't named working the easy way, such as a projector you plug in
once, add an entry with an empty name (`output = "";`) at the end. An empty name
matches any output that no other entry covers.

## Mirroring

To show the same picture on two screens, for example a projector that copies your
laptop, point one output at the other through `extraSettings`:

```nix
marchyo.monitors = [
  { output = "eDP-1"; }
  {
    output = "HDMI-A-1";
    extraSettings.mirror = "eDP-1";
  }
];
```

## Workspaces per monitor

By default every monitor gets its own workspaces 1 to 10. Hyprland numbers workspaces
globally, so each monitor owns a block of ten ids: the first monitor 1 to 10, the next
11 to 20, and so on. `Super + 1…0` go to a slot in the focused monitor's block, and
each bar labels its monitor's workspaces 1 to 10.

- A block belongs to the physical monitor, matched by make, model and serial rather
  than by connector, so a monitor gets the same block each time it comes back.
- The laptop panel (`eDP*`, `LVDS*`, `DSI*`) takes the first free block. When
  `marchyo.monitors` is set, its enabled outputs claim blocks in list order first.
- When a monitor is unplugged, its workspaces that hold windows join the block of the
  monitor they land on, and return under their old numbers when it comes back.

The assignment is kept in `$XDG_STATE_HOME/marchyo/monitors/workspaces` (and
`workspaces-merged` for the moved workspaces). `marchyo monitor workspaces reset`
removes both files and reloads Hyprland, which gives the monitors plugged in now new
blocks.

To use one global set of workspaces instead:

```nix
marchyo.workspaces.perMonitor = false;
```

## Live changes with the display panel

For a one-off, such as a borrowed screen at a meeting, you don't need to edit your
configuration. Press `Super + Ctrl + D` to open the display panel. It shows one
display at a time (a button per display when there are several) and sets:

- on/off, so long as another display stays on
- brightness: the laptop panel through `brightnessctl`, external monitors through
  `ddcutil` (see Brightness below)
- scale, snapped to values the resolution divides into whole pixels
- resolution: the native one, then smaller modes of the same aspect ratio down to 1080p
- refresh rate, when the display offers a rate above 60 Hz at that resolution
- rotation: right-click a display in the layout map to turn it 0, 90, 180 or 270 degrees
- Extend or Mirror, for the built-in panel and the external displays

With more than one display, drag a display in the layout map to place it beside
another; displays never overlap, and when a change makes a display larger or smaller
the displays next to it shift with it.

The panel applies a change right away and saves it to
`$XDG_STATE_HOME/marchyo/monitors/settings`, keyed by make, model and
serial, so a dock that renames its ports keeps each monitor's settings. Saved
settings survive rebuilds, win over `marchyo.monitors`, and apply to a monitor
plugged in later. Two commands manage them:

- `marchyo monitor save --nix` prints the current layout as a `marchyo.monitors`
  snippet, so you can make it permanent.
- `marchyo monitor reset` forgets the saved settings, so `marchyo.monitors` decides
  again.

If you want the panel to change only the current session, set
`marchyo.monitorPanel.persist = false`; the settings file is then neither read nor
written.

The system menu (`Super + Alt + Space`, **Setup**, **Monitors**) opens hyprmon, a
terminal tool for arranging outputs on the fly. Its changes don't survive a rebuild.

## Scaling on the fly

Press `Super + backslash` to step the scale of the monitor you're focused on:
1, 1.25, 1.5, 1.75, 2, and back to 1. It's the quickest way to find a comfortable
size for a new screen. Some panels skip a step, because Hyprland only accepts scales
that divide the resolution into whole pixels. The same thing runs from a terminal as
`marchyo monitor scale-cycle`.

Like hyprmon, this is a live change. Once you've settled on a value, set `scale` for
that output in `marchyo.monitors`.

## Laptops and external screens

When you're docked and only want the big screen, press `Super + Ctrl + Delete` to
turn the laptop's built-in panel off. Press it again to bring the panel back. From a
terminal it's `marchyo monitor laptop-toggle`. To keep the built-in panel off
permanently, give it `enable = false` in `marchyo.monitors`.

Closing the lid suspends the machine unless an external display is connected; then the laptop panel turns off and the session keeps running on the external display (`marchyo.power.lid`).

## Brightness

On a laptop, the brightness keys control the built-in panel. External monitors that
support DDC/CI can be controlled over their cable too: with the desktop on, Marchyo
installs `ddcutil` and gives your user access to it, so `ddcutil setvcp 10 70` sets
an external screen to 70% brightness. If you'd rather not grant that access, set
`marchyo.hardware.ddc.enable = false`.

## Graphics cards

Which GPU drivers your system uses is a separate setting,
`marchyo.graphics.vendors`. Set it to the GPUs in your machine, for example
`[ "amd" ]` or `[ "intel" "nvidia" ]`:

```nix
marchyo.graphics.vendors = [ "intel" ];
```

With more than one GPU, also say which one drives the display:

```nix
marchyo.graphics = {
  vendors = [ "intel" "amd" ];
  primary = "amd";
};
```

Run a single app on the other GPU with `DRI_PRIME=1 <app>`, or on an NVIDIA
laptop in offload mode with `nvidia-offload <app>`.

NVIDIA drivers and hybrid laptops have more options. The Graphics
page in the configuration reference on the site covers them in full.
