---
title: Default Apps
description: The apps Marchyo picks for you — browser, editor, players — and how to swap them.
---

Marchyo makes the app choices for you. Enable the desktop and you get a browser, an
editor, a file manager, and media players, all installed and registered as the system
defaults so that clicking a link opens the browser and opening a video opens the
player. You don't have to accept the picks — every one is a single option you can
change — but you start from a working set, not an empty menu.

All of these live under `marchyo.defaults.*`. Change one, rebuild, and the new app is
installed and wired up as the handler for its file types.

## What you can set

| Category | Default | Other choices |
|----------|---------|---------------|
| `browser` | `google-chrome` | `brave`, `firefox`, `chromium` |
| `editor` | `emacs` | `emacs`, `vscode`, `vscodium`, `zed` |
| `terminalEditor` | `emacs` | `emacs`, `neovim`, `helix`, `nano` |
| `videoPlayer` | `mpv` | `vlc`, `celluloid` |
| `audioPlayer` | `mpv` | `cmus`, `vlc`, `amberol` |
| `musicPlayer` | `spotify-player` | `ncspot`, `spotify` |
| `fileManager` | `nautilus` | `thunar` |
| `terminalFileManager` | `yazi` | `ranger`, `lf` |
| `imageEditor` | `pinta` | `gimp`, `krita` |
| `email` | `aerc` | `neomutt`, `gmail`, `outlook` |

For example, to run Firefox and VS Code instead of the defaults:

```nix
marchyo.defaults = {
  browser = "firefox";
  editor = "vscode";
};
```

A couple of notes on the choices. `gmail` and `outlook` for email aren't installed
apps — they just open the web version in your browser. And `spotify-player` and the
TUI mail clients are installed but need you to sign in before they do anything; the
music client opens in a floating terminal on `Super + M`.

## The terminal is always Ghostty

You'll notice there's no `terminal` option. That's deliberate — the terminal is
always Ghostty, deeply integrated with the rest of the desktop and the theme, so it
isn't one of the swappable defaults. Everything else is yours to change.

## Turning off management

Set any category to `null` and Marchyo stops installing or configuring it — useful if
you'd rather manage that app yourself:

```nix
marchyo.defaults = {
  browser = null;      # I'll handle the browser
  musicPlayer = null;  # don't install one
};
```

## About the default editor

The default editor is `emacs`: Marchyo installs `pkgs.emacs` and points
`$VISUAL`/`$EDITOR` at `emacsclient` (with a plain-Emacs fallback when no
daemon is running). If you'd rather use something else, switch `editor`
(and `terminalEditor`) to something from the lists above.
