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

## How the keys are laid out

Each modifier set has a main job:

- `Super + key`: the core apps and window actions (plain letters, not
  `Super + Shift` as in omarchy).
- `Super + Shift + key`: the shell panels, window moves and web apps.
- `Super + Ctrl + key`: utilities, toggles and menus.
- `Super + Alt + key`: window groups, Emacs-aware focus and extra launchers.

Adding `Shift` to a chord often reverses it (`Super + Tab` / `Super + Shift + Tab`,
`Super + Ctrl + J` / `Super + Ctrl + Shift + J`).

## Launching apps

| Keys | Action |
|------|--------|
| `Super + Return` | Terminal (Ghostty) |
| `Super + B` | Web browser |
| `Super + F` | File manager |
| `Super + Alt + Shift + F` | File manager at the focused terminal's cwd |
| `Super + E` | Editor |
| `Super + O` | Obsidian |
| `Super + G` | Messenger |
| `Super + /` | Password manager (focuses 1Password if open) |
| `Super + R` | App launcher (in-shell) |
| `Super + .` | Emoji picker (in-shell) |
| `Super + M` | Music player |
| `Super + Alt + C` | Calculator (qalc) |
| `Super + Alt + T` | Activity (btop) |
| `Super + Shift + I` | Input-method config (fcitx5) |
| `Super + Alt + Return` | tmux "Work" session |

### Web apps

With `marchyo.webapps.enable` (on by default with the desktop), a set of sites
opens as standalone browser app windows on `Super + Shift` chords:

| Keys | Action |
|------|--------|
| `Super + Shift + A` | ChatGPT |
| `Super + Shift + G` | GitHub |
| `Super + Shift + Y` | YouTube |
| `Super + Shift + W` | WhatsApp |
| `Super + Shift + Z` | Zoom |
| `Super + Shift + X` | X |
| `Super + Shift + P` | Google Photos |

Discord, Google Calendar, and Gmail are registered as launchers but ship no
default key. Start them from the app launcher, or give them one via
`marchyo.webapps.apps`.

## Window management

| Keys | Action |
|------|--------|
| `Super + W` or `Super + Q` | Close active window |
| `Super + J` | Toggle split direction |
| `Super + T` | Toggle floating |
| `Super + P` | Toggle pseudo-tile |
| `Super + Ctrl + J` / `Super + Ctrl + Shift + J` | Cycle the workspace layout (dwindle, scrolling, master) forward / back |
| `Super + Alt + D` | Minimize the window to the Drawer (`Super + D` shows it) |
| `Super + Alt + O` | Pop the window out (float, pin, centre) |
| `Super + ←/→/↑/↓` | Move focus |
| `Super + Shift + ←/→/↑/↓` | Swap window in a direction |
| `Alt + Tab` | Cycle windows on the workspace |
| `Super + minus` / `Super + equal` | Resize active window horizontally |
| `Super + Shift + minus` / `Super + Shift + equal` | Resize active window vertically |
| `Super + Page_Up` | Full screen |
| `Super + Ctrl + F` | Tiled full screen |
| `Super + Alt + F` | Full width |
| `Super + Ctrl + Alt + F` | Toggle full screen desktop |
| `Super + Left-drag` | Move window (mouse) |
| `Super + Right-drag` | Resize window (mouse) |

### Universal clipboard

| Keys | Action |
|------|--------|
| `Super + A` | Select all (sends `Ctrl + A`) |
| `Super + C` | Copy (`Ctrl + Shift + C` in terminals, `Ctrl + Insert` elsewhere) |
| `Super + V` | Paste (`Ctrl + Shift + V` in terminals, `Shift + Insert` elsewhere) |
| `Super + X` | Cut (sends `Ctrl + X`) |
| `Super + Ctrl + V` | Clipboard history (in-shell from cliphist) |

### Window grouping (tabbed/stacked)

| Keys | Action |
|------|--------|
| `Super + Alt + G` | Toggle window grouping |
| `Super + Alt + Shift + G` | Move window out of the group |
| `Super + Alt + ←/→/↑/↓` | Move window into a group in that direction |
| `Super + Alt + Tab` / `Super + Alt + Shift + Tab` | Next / previous window in group |

## Workspaces & drawer

Every monitor has its own workspaces 1–10 (`marchyo.workspaces.perMonitor`, on
by default). The keys act on the focused monitor, and each bar labels its own
monitor's workspaces 1–10. See [Monitors](./12-monitors.md).

| Keys | Action |
|------|--------|
| `Super + 1…0` | Switch to workspace 1–10 of the focused monitor |
| `Super + Shift + 1…0` | Move active window to workspace 1–10 of the focused monitor |
| `Super + Shift + Alt + 1…0` | Move window there silently (don't follow) |
| `Super + Tab` / `Super + Shift + Tab` | Next / previous workspace on the focused monitor |
| `Super + Ctrl + Tab` | Former workspace on the focused monitor |
| `Super + scroll` | Scroll through the focused monitor's workspaces |
| `Super + D` | Toggle the Drawer (scratchpad workspace) |
| `Super + Shift + D` | Send active window to the Drawer |

## Multi-monitor

| Keys | Action |
|------|--------|
| `Ctrl + Alt + Tab` / `Ctrl + Alt + Shift + Tab` | Focus next / previous monitor |
| `Super + Shift + ,` / `Super + Shift + .` | Move the active window to the previous / next monitor |
| `Super + Shift + Ctrl + ←/→/↑/↓` | Move the active window to the monitor in that direction |
| `Super + Shift + Alt + ←/→/↑/↓` | Move the whole workspace to an adjacent monitor, where it joins that monitor's workspaces |
| `Super + backslash` | Cycle focused monitor scale |
| `Super + Ctrl + Delete` | Toggle laptop display |

## Panels & menus

With the shell on (the desktop default), the panel binds reach the running shell
through Hyprland global shortcuts (`marchyo:<name>`), with no process started.
`marchyo shell toggle <panel>` and `marchyo shell overview` run the same actions
from a terminal. `Super + Ctrl + A` (wiremix) and `Super + Ctrl + W` (nmtui) open
the terminal audio mixer and Wi-Fi manager with the shell on or off.

| Keys | Action |
|------|--------|
| `Super + Escape` | System menu (lock, suspend, hibernate with `marchyo.power.hibernation.enable`, log out, restart shell, reboot, reboot to firmware, shut down) |
| `Super + Alt + Space` | Command menu (apps, capture, toggle, appearance, hardware, system, setup, share); type to search every entry, `Enter` opens or runs, `Esc` or `Backspace` on an empty field goes up a level |
| `Super + Ctrl + C` / `Super + Ctrl + Shift + X` / `Super + Ctrl + Shift + H` | Capture / toggle / hardware menu |
| `Super + Ctrl + Shift + T` | Theme menu |
| `Super + K` | Keybindings cheat sheet, grouped by modifier plane; search the description or the chord, `Enter` runs the bind |
| `Super + Shift + V` | Audio panel |
| `Super + Shift + N` | Network panel |
| `Super + Shift + B` | Power panel |
| `Super + Shift + M` | System monitor panel |
| `Super + Shift + Q` | Control Center (volume and mic sliders, quick-toggle tiles) |
| `Super + Ctrl + A` | Audio mixer (wiremix) |
| `Super + Ctrl + W` | Wi-Fi manager (nmtui) |
| `Super + Ctrl + B` | Bluetooth panel (power, scan, connect and pair); bluetui with the shell off |
| `Super + Ctrl + Shift + B` | Bluetooth manager (bluetui) |
| `Super + Ctrl + D` | Display panel |
| `Super + Ctrl + T` | Theme picker: a grid of theme previews; arrows move, `Enter` applies, `Escape` closes |
| `Super + Ctrl + Shift + W` | Wallpaper picker: the same grid for wallpapers |
| `Super + Ctrl + Space` | Next background |
| `` Super + ` `` | Window overview: every workspace with live window previews; type to filter by title or class, arrows / `Tab` to move, `Enter` to focus, `Escape` to close |
| `Super + Ctrl + Alt + E` | World clock |
| `Super + Ctrl + U` | What's new: the NEWS entries since you last looked |
| `Super + Ctrl + H` | First-login setup checklist |
| `Super + Ctrl + Alt + P` | Speed test (network and disk) |
| `Super + Ctrl + Alt + D` | Dropbox panel |
| `Super + Ctrl + Alt + G` | Ui gallery (developer) |
| `Super + Shift + Space` | Toggle the top bar |

## Notifications

Shell only.

| Keys | Action |
|------|--------|
| `Super + ,` | Dismiss the last notification |
| `Super + Ctrl + Alt + ,` | Dismiss, invoke or focus the newest notification |
| `Super + Ctrl + Shift + ,` | Dismiss all notifications |
| `Super + Alt + ,` | Control notifications with the keyboard: number keys press buttons, Enter clicks, Up/Down move, Delete dismisses, Escape ends |
| `Super + Ctrl + ,` | Toggle do-not-disturb |
| `Super + N` | Notification history |

In the history, Up and Down walk the rows, Enter opens the row's link or the sender's window, Delete removes it and Escape closes the panel.

## Screenshots, recording & OCR

| Keys | Action |
|------|--------|
| `Super + S`, `Super + Ctrl + Alt + C` or `Print` | Screenshot a region/window (copy + save) |
| `Super + Shift + S` (or `Super + Shift + Print`) | Screenshot a region and annotate (satty) |
| `Super + Ctrl + S` (or `Shift + Print`) | Screenshot the active window |
| `Super + Alt + S` (or `Ctrl + Print`) | Screenshot the current screen |
| `Super + Ctrl + Alt + S` (or `Alt + Print`) | Screenshot all screens |
| `Super + Shift + O` (or `Super + Ctrl + Shift + S`) | OCR a region → text to clipboard (tesseract) |
| `Super + Alt + Print` | Toggle screen recording |
| `Super + Shift + C` | Pick a color (hex to clipboard) |

Screenshots land in `~/Pictures/Screenshots`. Annotation and OCR can be turned
off with the Home Manager options `marchyo.screenshot.enableAnnotation` / `enableOcr`.

## Dictation

Dictation needs `marchyo.dictation.enable`.

| Keys | Action |
|------|--------|
| `F9` (hold) | Push-to-talk dictation |
| `Super + Ctrl + X` | Toggle recording on/off |
| `Super + Shift + H` | Floating dictation status window (voxtype backend only) |

## Quick actions & toggles

| Keys | Action |
|------|--------|
| `Super + Ctrl + Alt + T` | Notify date/time |
| `Super + Ctrl + Alt + B` | Notify battery status |
| `Super + Ctrl + R` / `Super + Ctrl + Alt + R` / `Super + Ctrl + Shift + R` | Set / show / clear reminders |
| `Super + Ctrl + period` | Transcode media file |
| `Super + Ctrl + I` | Toggle idle lock |
| `Super + Ctrl + K` | Toggle caffeine (keep awake) |
| `Super + Ctrl + N` | Toggle nightlight |
| `Super + Shift + L` | Cycle theme |
| `Super + Ctrl + Z` / `Super + Ctrl + Shift + Z` / `Super + Ctrl + Alt + Z` | Zoom in / out / reset (magnifier) |

## Session

| Keys | Action |
|------|--------|
| `Super + L` | Lock the screen (the shell lock; hyprlock with the shell off) |
| `Ctrl + Alt + Delete` | Power off |
| Volume / brightness / media keys | `XF86` laptop keys (volume, mic mute, brightness, play/pause/next/prev) |

## Emacs

With `marchyo.emacs.enable`:

| Keys | Action |
|------|--------|
| `Super + Shift + E` | New Emacs frame |
| `Super + Ctrl + E` | Emacs everywhere (edit the focused text field) |
| `Super + Z` | Emacs scratchpad |
| `Super + Alt + H/J/K/L` | Focus window, Emacs windows first |
| `Super + Alt + Shift + H/J/K/L` | Swap window, Emacs windows first |
| `Super + Shift + T` | Org capture |

## Top bar mouse actions

The top bar isn't only for reading — most segments respond to clicks and scrolls.
Those are covered in [The Top Bar](./05-the-top-bar.md).

## Changing a bind

Every bind comes from one table, `lib/keybinds.nix`, which
`modules/home/keybinds.nix` renders into Hyprland binds and into
`~/.config/marchyo/keybindings.json` for the `Super + K` cheat sheet. To change
a bind, override `wayland.windowManager.hyprland.settings` in your Home Manager
configuration; edits to the generated files are lost on the next rebuild.

With `marchyo.shell.enable = false`, hyprlock locks the screen and the
shell-only binds (launcher, panels, notifications) are absent.
