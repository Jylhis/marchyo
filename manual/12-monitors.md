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

## Live changes with hyprmon

For a one-off, such as a borrowed screen at a meeting, you don't need to edit your
configuration. Open the system menu with `Super + Alt + Space`, choose **Setup**,
then **Monitors**. That opens hyprmon, a terminal tool for arranging, resizing, and
enabling outputs on the fly.

Changes made in hyprmon apply right away but don't survive a rebuild. When you've
found an arrangement you like, copy it into `marchyo.monitors` so it sticks.

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

Closing the lid suspends the machine, the system's standard behavior. If you've
turned on hibernation with `marchyo.power.hibernation.enable`, closing the lid uses
suspend-then-hibernate instead: the machine suspends first so it wakes quickly, then
hibernates after 45 minutes so a longer break draws no power. Set
`marchyo.power.hibernation.suspendThenHibernate = false` to keep plain suspend on
lid close.

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

NVIDIA drivers and hybrid laptops with two GPUs have more options. The Graphics
page in the configuration reference on the site covers them in full.
