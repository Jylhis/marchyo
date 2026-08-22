---
title: Hotkeys
description: The complete keyboard map — apps, windows, capture, menus, and toggles.
---

This is the full keyboard map for the Marchyo desktop. It's a reference — you don't
need to memorize it. Skim it once to see what's possible, then come back when you
need a specific bind. If you'd rather search than scroll, press `Super + K` at any
time for a live, searchable cheat sheet drawn from your own configuration.

Throughout, **`Super`** is the primary modifier — the Windows or Command key. Nearly
every shortcut starts there.

:::tip
New here? [Navigation](./04-navigation.md) teaches the handful of binds you need to
start moving around, without the full list.
:::

## Launching apps

Hold `Super` and press a letter to launch an app. (Coming from omarchy? These are
plain `Super + <letter>` chords, not `Super + Shift`.)

| Keys | Action |
|------|--------|
| `Super + Return` | Terminal (Ghostty) |
| `Super + B` | Web browser |
| `Super + F` | File manager |
| `Super + R` | App launcher (vicinae) |
| `Super + M` | Music player |
| `Super + E` | Editor |
| `Super + O` | Obsidian |
| `Super + G` | Messenger |
| `Super + /` | Password manager (focuses 1Password if open) |
| `Super + A` | AI chat (when AI is enabled) |
| `Super + .` | Emoji picker |
| `Super + Shift + I` | Input-method config (fcitx5) |

### Web apps

A set of sites open as their own standalone windows on `Super + Shift` chords:

| Keys | Action |
|------|--------|
| `Super + Shift + A` | ChatGPT |
| `Super + Shift + G` | GitHub |
| `Super + Shift + Y` | YouTube |
| `Super + Shift + W` | WhatsApp |
| `Super + Shift + Z` | Zoom |
| `Super + Shift + X` | X |
| `Super + Shift + P` | Google Photos |

Discord, Google Calendar, and Gmail are registered too but ship no default key —
open them from the launcher, or give them a key of your own.

## Window management

| Keys | Action |
|------|--------|
| `Super + W` | Close active window |
| `Super + J` | Toggle split direction |
| `Super + T` | Toggle floating |
| `Super + P` | Toggle pseudo-tile |
| `Super + ←/→/↑/↓` | Move focus |
| `Super + Shift + ←/→/↑/↓` | Swap window in a direction |
| `Alt + Tab` | Cycle windows on the workspace |
| `Super + minus` / `Super + equal` | Resize horizontally |
| `Super + Shift + minus` / `Super + Shift + equal` | Resize vertically |
| `Super + Page_Up` | Full screen |
| `Super + Ctrl + F` | Tiled full screen |
| `Super + Alt + F` | Full width |
| `Super + Left-drag` | Move window (mouse) |
| `Super + Right-drag` | Resize window (mouse) |

### Universal clipboard

These work everywhere, including the terminal, because they send terminal-safe key
sequences under the hood:

| Keys | Action |
|------|--------|
| `Super + C` | Copy |
| `Super + V` | Paste |
| `Super + X` | Cut |

### Window grouping (tabbed/stacked)

Group several windows into one tiled slot and tab between them:

| Keys | Action |
|------|--------|
| `Super + Alt + G` | Toggle window grouping |
| `Super + Alt + Shift + G` | Move window out of the group |
| `Super + Alt + ←/→/↑/↓` | Move window into a group in that direction |
| `Super + Alt + Tab` / `Super + Alt + Shift + Tab` | Next / previous window in group |

## Workspaces & scratchpad

| Keys | Action |
|------|--------|
| `Super + 1…5` | Switch to workspace (on the current monitor) |
| `Super + Shift + 1…0` | Move active window to workspace 1–10 |
| `Super + Shift + Alt + 1…0` | Move window there silently (don't follow) |
| `Super + Tab` / `Super + Shift + Tab` | Next / previous workspace |
| `Super + Ctrl + Tab` | Former workspace |
| `Super + scroll` | Scroll through workspaces |
| `Super + D` | Toggle the Drawer (scratchpad) |
| `Super + Shift + D` | Send active window to the Drawer |

## Multi-monitor

| Keys | Action |
|------|--------|
| `Ctrl + Alt + Tab` / `Ctrl + Alt + Shift + Tab` | Focus next / previous monitor |
| `Super + Shift + ,` / `Super + Shift + .` | Move window to the adjacent monitor |
| `Super + Shift + Alt + ←/→/↑/↓` | Move the whole workspace to an adjacent monitor |

## Screenshots, clipboard & OCR

| Keys | Action |
|------|--------|
| `Super + S` (or `Print`) | Screenshot a region/window (copy + save) |
| `Super + Shift + S` | Screenshot a region and annotate |
| `Super + Ctrl + S` | Screenshot the active window |
| `Super + Alt + S` | Screenshot the current screen |
| `Super + Ctrl + Alt + S` | Screenshot all screens |
| `Super + Shift + O` | OCR a region → text to clipboard |
| `Super + Ctrl + V` | Clipboard history |
| `Super + Shift + C` | Pick a color (hex to clipboard) |

Screenshots land in `~/Pictures/Screenshots`.

## Menus & utilities

| Keys | Action |
|------|--------|
| `Super + Escape` | Power/session menu (lock, suspend, hibernate, reboot, shutdown) |
| `Super + Alt + Space` | Central system menu |
| `Super + K` | Keybindings cheat sheet (searchable, from your live config) |
| `Super + Ctrl + comma` | Toggle notification do-not-disturb |
| `Super + Ctrl + Shift + comma` | Dismiss all notifications |
| `Super + Ctrl + R` | Set a reminder |
| `Super + Ctrl + Alt + R` | Show pending reminders |
| `Super + Ctrl + Shift + R` | Clear reminders |
| `Super + Ctrl + Alt + T` | Notify date/time |
| `Super + Ctrl + Alt + B` | Notify battery status |
| `Super + Ctrl + period` | Transcode media file |
| `Super + backslash` | Cycle focused monitor scale |
| `Super + Ctrl + Delete` | Toggle laptop display |
| `Super + Ctrl + A` | Audio mixer (wiremix) |
| `Super + Ctrl + B` | Bluetooth (bluetui) |
| `Super + Ctrl + W` | Wi-Fi (nmtui) |
| `Super + Alt + Return` | tmux "Work" session |
| `Super + Alt + D` | lazydocker (needs development tools) |
| `Super + Alt + Shift + F` | File manager at the focused terminal's directory |

## Dictation

Dictation needs `marchyo.dictation.enable`. Once it's on:

| Keys | Action |
|------|--------|
| `F9` (hold) | Push-to-talk dictation |
| `Super + Ctrl + X` | Toggle recording on/off |
| `Super + Shift + H` | Floating dictation status window |

## System & session

| Keys | Action |
|------|--------|
| `Super + L` | Lock the screen |
| `Ctrl + Alt + Delete` | Power off |
| `Super + Shift + Space` | Toggle the top bar (Waybar) |
| `Super + ,` | Dismiss last notification |
| `Super + Ctrl + I` | Toggle idle lock (keep-awake) |
| `Super + Ctrl + N` | Toggle night light |
| `Super + Alt + Print` | Toggle screen recording |
| `Super + Ctrl + Z` / `Shift + Z` / `Alt + Z` | Zoom in / out / reset (magnifier) |
| Volume / brightness / media keys | The laptop function keys work as labelled |

## Top bar mouse actions

The top bar isn't only for reading — most segments respond to clicks and scrolls.
Those are covered in [The Top Bar](./05-the-top-bar.md).
