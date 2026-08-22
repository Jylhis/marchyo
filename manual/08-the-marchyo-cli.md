---
title: The Marchyo CLI
description: One command that drives the whole desktop — toggles, themes, capture, and system management.
---

Every Marchyo system ships one command: `marchyo`. It's the single control surface
for the desktop. When you press a keybinding, click a segment on the top bar, or open
a menu, it's `marchyo` doing the work behind the scenes — and you can run the same
actions yourself from any terminal.

Run `marchyo status` any time for a dashboard of how your system is currently set up.

## Runtime now, or persist forever

Here's the idea that makes the CLI worth learning. Marchyo is a declarative system —
normally you change things by editing your configuration and rebuilding. But you don't
always want to rebuild just to try a darker theme or toggle the gaps between windows.
So every command that *changes* something offers three modes:

- **By default, it changes things live.** The effect is instant — no rebuild — and
  it's remembered across compositor restarts. This is the mode you'll use constantly:
  fast, reversible, low-stakes. A live change resets on the next full rebuild.
- **`--apply` makes it stick.** Add this flag and the change is also written down and
  rebuilt into your system, so it survives reboots. Your hand-written configuration
  still wins if it disagrees — `--apply` sets a default, not an override.
- **`--revert` undoes it.** Drops the live change, puts the declared value back, and
  cleans up anything `--apply` persisted.

So the rhythm is: try it live, and if you love it, run the same command with
`--apply`. A few commands (`install`, `remove`, `webapp`, `security`) always rebuild,
because there's no meaningful "live" version of installing software.

## What you can do

### Theme and wallpaper

```bash
marchyo theme list           # switchable themes, active one marked
marchyo theme set <name>     # switch now (dark / light alias the Jylhis pair)
marchyo theme next           # cycle
marchyo bg set <path>        # set the wallpaper
marchyo bg next              # cycle wallpapers
```

### Toggles

`marchyo toggle <name>` flips a desktop feature on or off, live. The switches include
`gaps`, `transparency`, `nightlight`, `waybar`, `touchpad`, `touchscreen`, `idle`,
`screensaver`, `notifications`, and `suspend`. Add `--status` to check one, or
`--apply` to make it permanent:

```bash
marchyo toggle nightlight            # on/off now
marchyo toggle gaps off --apply      # and keep it that way
```

### Capture

```bash
marchyo capture screenshot [--target area|active|output|screen] [--edit]
marchyo capture record [--audio none|desktop|mic]   # run again to stop
marchyo capture ocr        # select a region, copy the recognized text
marchyo capture color      # color picker, hex to clipboard
```

### Menus, launching, and session

```bash
marchyo menu [power]         # the central system menu, or the power menu
marchyo keybindings          # searchable cheat sheet
marchyo launch <app>         # launch an app detached from the terminal
marchyo lock                 # also: logout, suspend, hibernate, reboot, shutdown
marchyo powerprofile set <p> # eco / balanced / performance
```

### Utilities

```bash
marchyo reminder set|show|clear     # reminders on lightweight timers
marchyo info datetime|battery       # quick pop-up notifications
marchyo transcode [file] [--to mp4|webm|gif]
marchyo font set <family>           # switch the terminal font live
```

### Managing the system

```bash
marchyo status               # current config + system info
marchyo rebuild              # rebuild against your flake
marchyo update               # update your flake inputs
marchyo upgrade              # update, then rebuild
marchyo rollback             # switch to the previous generation
marchyo gc                   # collect old generations
marchyo diff                 # what changed between generations
```

The update and rollback commands are covered in more depth in
[Updating](./11-updating.md). You can also flip whole feature groups on and off —
`marchyo install development`, `marchyo remove media` — and add web-app windows with
`marchyo webapp add <url>`; those always rebuild.

## Text or JSON, quiet or loud

Most commands take `--format text|json` (or `--json`) if you want to script against
them, plus `--plain`, `--no-color`, `-q` for quiet and `-v` for verbose. Data goes to
standard output and diagnostics to standard error, so piping works cleanly.

## A stable contract

As of 1.0, the command names, arguments, and flags are frozen until 2.0 — new things
may be *added* in 1.x, but nothing you learn here will be renamed or removed under
you. You can build habits and scripts on it safely.
