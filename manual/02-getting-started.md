---
title: Getting Started
description: From a fresh install to your first rebuild — the loop you'll use forever.
---

Getting onto Marchyo means writing a small configuration and building it once.
After that, every change you ever make follows the same short loop: edit the
configuration, rebuild, done. This chapter walks you from nothing to a running
desktop, and introduces that loop — the one habit the whole system is built around.

You'll want NixOS already installed (or a machine you can install it on), and a
terminal. Everything below happens in a directory that holds one file describing
your system.

## The fastest path: the workstation template

Marchyo ships a ready-made workstation configuration. Starting from it is the
quickest way to a complete desktop, and it's the path this chapter follows.

Create a new directory, then pull in the template:

```bash
nix flake init -t github:Jylhis/marchyo#workstation
```

That drops a `flake.nix` and a `configuration.nix` into the directory — a full
setup with the Hyprland desktop, development tools, and sensible defaults already
switched on.

Next, capture your machine's hardware so NixOS knows what it's building for:

```bash
nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

## Make it yours

Open `configuration.nix` and change the handful of things that are personal to you:

- `networking.hostName` — what your machine is called.
- `marchyo.users.developer` — your name and email; rename the user if you like.
- `marchyo.timezone` and `marchyo.defaultLocale` — the defaults are
  `Europe/Zurich` and `en_US.UTF-8`; set your own if they don't fit.
- `marchyo.development.enable` — the developer toolchain is one switch; set it to
  `false` if you don't want it.

You don't need to touch anything else to get a working desktop. The template already
enables `marchyo.desktop.enable`, and that one flag cascades into media and office
apps, the theme, the bar, and the keybindings.

## Try it in a VM first (optional)

If you'd rather see it before you commit, build a throwaway virtual machine and boot
it:

```bash
nixos-rebuild build-vm --flake .#workstation
./result/bin/run-workstation-vm
```

You get the real desktop in a window, with no risk to your actual system.

## Build and switch

When you're ready, build the configuration and switch your running system onto it:

```bash
sudo nixos-rebuild switch --flake .#workstation
```

The first build takes a while — it's fetching and assembling the whole desktop.
When it finishes, log in and you're on Marchyo. Press `Super + K` to see every
keybinding, or jump to [Navigation](./04-navigation.md) to start moving around.

## The loop you'll use forever

That last command is the loop. From now on, *every* change to your system is the
same three steps:

1. **Edit** `configuration.nix` — flip a `marchyo.*` option, add a package, change
   your theme variant.
2. **Rebuild** with `sudo nixos-rebuild switch --flake .#workstation`.
3. **Live with it** — and if you don't like it, undo it the same way, or roll back.

There is no separate "install" step and no editing of dotfiles by hand. Want a
different browser? Set `marchyo.defaults.browser` and rebuild. Want the light theme?
Set `marchyo.theme.variant = "light"` and rebuild. The configuration is the system.

Once the desktop is running, the [marchyo CLI](./08-the-marchyo-cli.md) gives you a
faster path for the everyday changes — switching themes, toggling features, capturing
the screen — without editing a file at all. But the rebuild loop is always underneath,
and [Updating](./11-updating.md) shows how it also keeps your system current and lets
you roll back safely.

## Other ways to install

The template is the easy path, but not the only one:

- **Add Marchyo to an existing flake.** If you already manage NixOS with a flake,
  add `marchyo` as an input and build with `marchyo.lib.mkNixosSystem`; it selects
  the right nixpkgs, Home Manager, and modules for you. On a Mac, `mkDarwinSystem`
  works the same way.
- **Home Manager only.** If you just want Marchyo's user environment on top of an
  existing Linux system, the `marchyo.lib.mkHomeConfiguration` builder wires up the
  Home Manager side alone.

The full flake wiring for these lives in the configuration reference on the site;
this manual assumes the workstation path from here on.
