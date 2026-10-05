---
title: Coming from Other Distros
description: Orientation for people arriving from Arch, omarchy, macOS, or Windows.
---

Most of what you know still applies on Marchyo. Hyprland is still Hyprland, a
terminal is still a terminal, and your browser works the way it always did. The one
real difference is how the system changes: you don't install things or edit settings
by hand. You describe what you want in your configuration and rebuild. This chapter
maps the habits you already have onto that idea.

## The golden rule

Never install anything imperatively. No `pacman -S`, no `apt install`, no
`pip install --user`, no `nix-env -i` or `nix profile install`, and no hand edits to
the files in `~/.config`. If you want something on your machine, add it to your
configuration and rebuild:

```nix
environment.systemPackages = with pkgs; [
  gimp
  inkscape
];
```

```bash
sudo nixos-rebuild switch --flake .#workstation
```

The same goes for settings. Many of the files in `~/.config` are generated from your
configuration, so a hand edit there is overwritten on the next rebuild. Change the
matching `marchyo.*` option instead. If you're not sure of a package's name,
`nix search nixpkgs <name>` looks it up without installing anything.

This feels slower for the first week. After that it pays you back: every change is
written down, every machine can be rebuilt identically, and a bad change is undone by
booting the previous generation (see [Updating](./10-updating.md)).

## From omarchy

You'll feel at home quickly. Marchyo takes omarchy's ideas and builds them
declaratively, so the shape of the desktop is familiar: Hyprland, a curated set of
apps chosen for you, one coherent theme, and a keyboard-first workflow. Many binds
match on purpose. `Super + Ctrl + A`, `Super + Ctrl + B`, and `Super + Ctrl + W`
open the audio mixer, Bluetooth, and Wi-Fi tools in floating terminals,
`Super + Escape` opens the power menu, and `Super + Alt + Space` opens the system
menu.

A few things differ:

- **App launch binds are plain `Super + <letter>`.** `Super + B` is the browser,
  `Super + F` the file manager, `Super + E` the editor, `Super + Return` the
  terminal. Web apps such as YouTube and GitHub sit on `Super + Shift` chords. The
  full map is in [Hotkeys](./07-hotkeys.md).
- **There is no `omarchy-install-*`.** Turning on a whole feature group is one flag,
  such as `marchyo.development.enable`, or the `marchyo install development` command,
  which edits your configuration and rebuilds for you.
- **Updating is `nixos-rebuild`.** Instead of a migration engine, your system is
  pinned in `flake.lock`. `marchyo upgrade` bumps it and rebuilds, and every rebuild
  leaves a generation you can roll back to.
- **One command instead of many scripts.** Where omarchy has its `omarchy-*`
  commands, Marchyo has a single `marchyo` command for themes, toggles, capture,
  menus, and web apps. See [The marchyo CLI](./08-the-marchyo-cli.md).

## From Arch

Pacman and the AUR go away. Packages come from nixpkgs, and you list them in your
configuration instead of installing them. You don't need to track partial upgrades
or `.pacnew` files: the whole system is rebuilt from one pinned set, so it is always
consistent. Services work the same way. Rather than `systemctl enable`, you enable
the service in your configuration, and it is started on rebuild.

The Arch Wiki is still useful for understanding how a tool works. When it tells you
to edit a file in `/etc` or install a package, translate that into the matching
NixOS or `marchyo.*` option.

## From macOS or Windows

The biggest change is the tiling compositor. Windows don't float wherever you drop
them. Each new window takes a share of the screen, and the layout rearranges itself
as you open and close things. You move between windows and workspaces with the
keyboard far more than with the mouse. [Navigation](./04-navigation.md) teaches the
handful of binds you need, and `Super + K` shows every bind any time you forget one.

`Super` is the key you already know as Command or the Windows key, and nearly every
shortcut starts with it. `Super + R` opens the app launcher, the closest thing to
Spotlight or the Start menu.

There is no settings app. Your settings live in `configuration.nix`: the browser is
`marchyo.defaults.browser`, the theme is `marchyo.theme.variant`, and so on. For the
quick, everyday changes, the system menu (`Super + Alt + Space`) and the
[marchyo CLI](./08-the-marchyo-cli.md) let you switch themes, flip toggles, and
connect to Wi-Fi without opening a file.

If you want to stay on your Mac, Marchyo can also manage it through nix-darwin. You
keep the macOS desktop and get Marchyo's shell, Git setup, fonts, packages, and
system defaults on top, built from the same kind of configuration.
