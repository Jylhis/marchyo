---
title: Navigation
description: Moving around the desktop — windows, workspaces, and tiling, by keyboard.
---

The Marchyo desktop is keyboard-driven. You *can* reach for the mouse, but almost
everything — launching apps, moving between windows, arranging them, hopping across
workspaces — is faster from the keyboard. This chapter teaches the mental model.
When you want the exhaustive key-by-key list, [Hotkeys](./07-hotkeys.md) has all of
it; here we cover just enough to feel at home.

One key does most of the work: **`Super`**, the Windows or Command key. Nearly every
Marchyo shortcut starts with it. If you remember only one thing, remember that
`Super` is where you begin.

## Launching things

To open an app, hold `Super` and press a letter. `Super + Return` gives you a
terminal, `Super + B` a browser, `Super + F` a file manager, `Super + E` your
editor. Don't remember the letter? `Super + R` opens the launcher — start typing a
name and press Enter.

:::note
If you're coming from omarchy, note the difference: Marchyo launches apps with
`Super + <letter>`, where omarchy uses `Super + Shift + <letter>`. The `Super +
Shift` chords here open **web apps** instead — `Super + Shift + G` for GitHub,
`Super + Shift + Y` for YouTube, and so on.
:::

## Tiling: windows arrange themselves

Marchyo tiles. When you open a window it takes the whole screen; open a second and
the space splits between them; a third splits again. You don't drag windows into
place — the compositor lays them out for you, and you nudge that layout with the
keyboard.

- **Move focus** between windows with `Super + ←/→/↑/↓` (the arrow keys).
- **Swap** two windows by adding Shift: `Super + Shift + ←/→/↑/↓` moves the active
  window in a direction.
- **Resize** the active window with `Super + minus` and `Super + equal`.
- **Cycle** through the windows on the current workspace with `Alt + Tab`.

When you're done with a window, `Super + W` closes it.

Sometimes tiling isn't what you want — a calculator, a small dialog, a picture. For
those, `Super + T` toggles the active window to *floating*, so it sits above the
tiled layout and you can move it with `Super + Left-drag`. `Super + Page_Up` throws
the current window to full screen and back.

## Workspaces: more room than one screen

A workspace is a full screen of windows. You get several, and you switch between
them instantly, which is the natural way to keep work separated — mail on one,
code on another, chat on a third.

- **Switch** to a workspace with `Super + 1` through `Super + 5`.
- **Send** the active window to another workspace with `Super + Shift + <number>`.
- **Flip** between the next and previous workspace with `Super + Tab` and
  `Super + Shift + Tab`, or scroll workspaces with `Super + scroll`.

There's also a **Drawer** — a scratchpad workspace that slides in over whatever
you're doing and slides away again. `Super + D` toggles it; `Super + Shift + D`
sends the current window into it. It's the right home for a music player, a
notes window, or anything you want one keystroke away but not underfoot.

## More than one monitor

Plug in a second display and Marchyo treats each screen as its own set of
workspaces. Move focus between monitors with `Ctrl + Alt + Tab`, and push the
active window to the next screen with `Super + Shift + ,` and `Super + Shift + .`.
Setting up the physical arrangement of your monitors is covered under
[Monitors](./13-monitors.md).

## When you forget a shortcut

You will forget shortcuts — everyone does at first. `Super + K` opens a searchable
cheat sheet built from your live configuration, so it always matches the system in
front of you. Type a word like "screenshot" or "workspace" and the matching binds
appear. It's the fastest way to learn the rest, and it's why the full list in
[Hotkeys](./07-hotkeys.md) is a reference you look things up in, not a page you have
to memorize.
