---
title: Welcome to Marchyo
description: What Marchyo is, who it's for, and the one idea that makes it different.
---

Marchyo is an opinionated, beautiful Linux desktop built on NixOS, Hyprland, and a
coherent design system — the ideas of [omarchy](https://omarchy.org), re-expressed
declaratively.

The one idea to hold onto: **your desktop is described, not tinkered with.** Every
app, keybind, theme, and service comes from a configuration you can read, version,
and roll back. When you want to change something, you change the description and
rebuild. Nothing drifts; nothing is a mystery three months later.

## The omakase idea

Marchyo follows omarchy's *omakase* philosophy — the chef chooses. Rather than hand
you an empty desktop and a thousand decisions, it ships a full set of curated
choices that already work together: the compositor, the bar, the launcher, the
terminal, the fonts, the keybindings, the color palette. You are meant to enjoy the
meal first and season it later.

That curation is the point. The defaults are chosen so the desktop looks good and
feels fast on the first boot, not after a weekend of configuration. When you do
want something different, every choice is a setting you can change — but you start
from a coherent whole, not a blank page.

## Described, not tinkered with

Most Linux desktops are shaped by hand: you install a package here, edit a dotfile
there, flip a system service, and over time the machine becomes a pile of small
decisions nobody wrote down. Marchyo takes the opposite approach. Your whole system
lives in a Nix configuration you own. To add an app, change your theme, or enable a
feature, you edit that configuration and rebuild.

What you gain is real: every change is reviewable, every machine is reproducible,
and every update can be undone by booting the previous generation. Nothing rots
silently, because nothing was ever set by hand.

What's new is honest too: you don't `apt install` or drag files into `~/.config`
anymore. Those dotfiles are *generated* from your configuration, so editing them by
hand gets overwritten on the next rebuild. The rebuild loop replaces the tinkering
loop. It takes a little getting used to, and then it's hard to go back — see
[Getting Started](02-getting-started) for the loop itself and
[Updating](./11-updating.md) for how change and rollback work.

## What's in the box

Enable the desktop and you get a complete, themed environment:

- **A Hyprland desktop** — a fast, keyboard-driven Wayland compositor, with Waybar
  across the top, the Vicinae launcher, notifications, clipboard history, and
  one-key screenshots, recording, and OCR.
- **Curated apps** — a browser, editor, terminal (Ghostty), file manager, and media
  players, all chosen for you and all swappable through a single set of options.
- **One coherent theme** — a design system that colors every surface at once, in a
  dark or light variant you can switch at runtime.
- **The `marchyo` CLI** — one command that drives the whole desktop: toggles,
  theme switching, capture, menus, and system management.
- **Optional AI** — a bring-your-own-key AI setup wired to OpenRouter, off until you
  turn it on.
- **More than one machine** — the same configuration builds a NixOS workstation, a
  nix-darwin Mac, or a nix-on-droid Android terminal.

## Who it's for

Marchyo is for people who want a desktop that is beautiful and fast out of the box,
and who like the idea of a machine they can describe, version, and reproduce. If
you came from omarchy, Arch, macOS, or Windows and want that same curated Hyprland
feel with NixOS underneath, you're in the right place.

It's a less natural fit if you want to install things imperatively and edit config
files live — that's exactly the workflow Marchyo trades away. You can always drop
down to raw Nix, but the whole system assumes you'll describe your changes rather
than make them by hand.

Ready? [Getting Started](./02-getting-started.md) takes you from an install to your
first rebuild.
