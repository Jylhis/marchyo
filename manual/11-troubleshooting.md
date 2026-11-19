---
title: Troubleshooting
description: Common snags, and the questions people ask first.
---

Most things that go wrong on Marchyo fall into a few buckets, and most have a quick
answer. Here are the ones people hit first.

## A rebuild fails

- **Something about an unknown option.** If a rebuild complains that a `marchyo.*`
  option doesn't exist, it usually means the option was renamed or removed (for
  example `marchyo.inputMethod.*`, now `marchyo.keyboard.layouts`). Check the
  [migration guide](/docs/guides/migration/) for the current name. Because the system is declarative,
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
  [Monitors](./12-monitors.md).
- **The theme doesn't look right.** Make sure theming is enabled
  (`marchyo.theme.enable = true`). If a runtime theme switch didn't stick after a
  rebuild, that's expected — runtime switches are temporary. See
  [Themes](./06-themes.md).
- **Dictation isn't typing.** Confirm `marchyo.dictation.enable` is on and that the
  dictation service is running (`systemctl --user status voxtype`). The push-to-talk key also needs your user to be in the
  `input` group, which Marchyo adds for you when push-to-talk is enabled. See
  [Dictation](/docs/configuration/dictation/).

## The desktop is frozen

When only the Hyprland compositor hangs, the kernel, the services and the network keep
running, but the screen and the keyboard do not answer. The terminals die with the
compositor. Try these in order and stop at the first one that works.

1. **Wait about 40 seconds.** The user unit `marchyo-compositor-watch` probes Hyprland
   with `hyprctl` every 10 seconds. After three failed probes in a row it saves
   evidence, sends SIGABRT to Hyprland (SIGKILL after 10 seconds) and the session
   returns to the greeter. It is on with `marchyo.desktop.enable`; turn it off with
   `marchyo.desktop.compositorWatch.enable = false`.
2. **Switch to a text console.** Press `Alt+SysRq+R` to take the keyboard from the
   compositor (this needs `marchyo.performance.crash.sysrq` to allow keyboard
   control, for example `180`), then `Ctrl+Alt+F3` and log in. Over SSH, log in as the
   same user instead.
3. **Run the rescue once.** `marchyo-compositor-watch --now` does the same capture and
   kill as the watchdog without the probe, prints where it saved the evidence, and the
   session returns to the greeter. Over SSH it needs the session's `XDG_RUNTIME_DIR`,
   for example `XDG_RUNTIME_DIR=/run/user/$(id -u) marchyo-compositor-watch --now`.
4. **Press the power key once, briefly.** logind runs a clean poweroff. Do not hold it.

### Where the evidence is

Each rescue writes `~/.local/state/marchyo/hyprland/hang-<time>/` with
`hyprland.log` (the Hyprland log, which otherwise lives on tmpfs), `status`
(`/proc/<pid>/status`), `threads` (`/proc/<pid>/task/*/stat`, one line per thread) and
`sched` (the scheduling policy from `chrt`). The SIGABRT also leaves a core dump:
`coredumpctl list Hyprland`. After a normal session end the last five Hyprland logs stay
in `~/.local/state/marchyo/hyprland/`. The watchdog's own log is
`journalctl --user -u marchyo-compositor-watch -b`.

With `marchyo.performance.flightRecorder.enable = true`, `sudo below replay -t "<time>"`
shows CPU, memory, pressure and process history around the hang.

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
Roll back to the previous generation. [Updating](./10-updating.md) covers exactly how,
including recovering from the boot menu if the system won't come up.
