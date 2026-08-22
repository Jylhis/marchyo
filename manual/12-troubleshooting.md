---
title: Troubleshooting
description: Common snags, and the questions people ask first.
---

Most things that go wrong on Marchyo fall into a few buckets, and most have a quick
answer. Here are the ones people hit first.

## A rebuild fails

- **Something about an unknown option.** If a rebuild complains that a `marchyo.*`
  option doesn't exist, it usually means the option was renamed or removed. Check the
  migration guide on the site for the current name. Because the system is declarative,
  a stale option name fails the build outright rather than silently doing nothing —
  which is the point: you find out immediately.
- **You want to check before committing to a full build.** A quick evaluation catches
  most option and typo mistakes in seconds without building anything. If you have a
  checkout of the Marchyo repo, that's `just check` (or `nix flake check`).

## The desktop misbehaves

- **A key does nothing, or I've forgotten the shortcut.** Press `Super + K` for the
  live, searchable cheat sheet — it always matches your actual system. The full list
  is in [Hotkeys](./07-hotkeys.md).
- **My monitors are laid out wrong.** Monitor arrangement is something you set in your
  configuration; the bundled `hyprmon` tool helps you position screens. See
  [Monitors](./13-monitors.md).
- **The theme doesn't look right.** Make sure theming is enabled
  (`marchyo.theme.enable = true`). If a runtime theme switch didn't stick after a
  rebuild, that's expected — runtime switches are temporary. See
  [Themes](./06-themes.md).
- **Dictation isn't typing.** Confirm `marchyo.dictation.enable` is on and that the
  dictation service is running. The push-to-talk key also needs your user to be in the
  `input` group, which Marchyo adds for you when push-to-talk is enabled.

## Questions people ask

**How does Marchyo relate to omarchy?**
Omarchy is DHH's Arch-plus-Hyprland distribution. Marchyo brings the same *kind* of
opinionated, beautiful Hyprland desktop to NixOS, but it's an independent, batteries-
included Nix flake rather than an Arch install — you get it declaratively. It's also
distinct from the community `omarchy-nix` port; Marchyo is its own configuration and
toolset.

**How do I change a default app?**
Set the matching `marchyo.defaults.*` option — browser, editor, file manager, music
player, email, and so on — then rebuild, or set it to `null` to stop managing that
category. The one exception is the terminal, which is always Ghostty. See
[Default Apps](./09-default-apps.md).

**Where does my configuration live?**
In your Nix configuration — nowhere else. The files under `~/.config` are *generated*
from it, so editing them by hand gets overwritten on the next rebuild. To change how
something behaves, set a `marchyo.*` option (or override the underlying module) and
rebuild.

**How do I undo a bad update?**
Roll back to the previous generation. [Updating](./11-updating.md) covers exactly how,
including recovering from the boot menu if the system won't come up.
