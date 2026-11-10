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
  fast, reversible, low-stakes. Live changes are kept in
  `~/.local/state/marchyo/runtime.json` and replayed after every login and
  home-manager activation (theme first, then wallpaper, fonts, appearance and
  toggles), so a rebuild does not drop them.
- **`--apply` makes it stick.** Add this flag and the change is also written to
  `/etc/marchyo/cli-state.json` and rebuilt into your system, so it survives reboots.
  Your hand-written configuration still wins if it disagrees — `--apply` sets a
  default, not an override.
- **`--revert` undoes it.** Drops the live change, puts the declared value back, and
  cleans up anything `--apply` persisted.

So the rhythm is: try it live, and if you love it, run the same command with
`--apply`. A few commands (`install`, `remove`, `webapp`) always rebuild,
because there's no meaningful "live" version of installing software.
`security enroll` only registers your fingerprint or key; turn the feature on
in your config first.

### Wiring `--apply` into your flake

Flake evaluation is pure, so Marchyo cannot read `/etc/marchyo/cli-state.json` itself.
To let `--apply` settings reach your system, read the file in your own flake:

```nix
{
  marchyoCliState =
    builtins.fromJSON (builtins.readFile /etc/marchyo/cli-state.json);
}
```

and rebuild with `--impure` (`marchyo rebuild` passes it for you).

## What you can do

### Theme and wallpaper

```bash
marchyo theme list           # switchable themes, active one marked
marchyo theme set <name>     # switch now (dark / light alias the Jylhis pair)
marchyo theme next           # cycle
marchyo bg set <path>        # set the wallpaper
marchyo bg list              # selectable wallpapers (theme, package, ~/Pictures/Wallpapers)
marchyo bg next              # cycle that list
marchyo theme gaps on        # window gaps (--apply keeps it)
marchyo theme transparency glassy   # opaque | transparent | glassy
marchyo theme corners rounded       # theme | sharp | rounded
marchyo theme generate <image>      # build a theme from a wallpaper (matugen)
marchyo theme bar-position bottom
marchyo theme bar-background glassy
marchyo bar put marchyo.cpu centerBegin   # edit the bar layout live (marchyo bar --help)
marchyo theme icons          # installed icon themes; give a name to set one
```

`bar list` shows the recorded layout edits and `bar reset` drops them; `bar position`
and `bar background` are the same as the `theme bar-*` commands. `bg list --format json`
reports `[{path, name, source, current}]`, and `theme list --format json` adds each
theme's `preview` and `wallpaper` paths when it ships them. Bar position, bar
background, reduce motion and the UI font live in
`$XDG_STATE_HOME/marchyo/shell/style.json`, which the shell watches.

Runtime changes survive a home-manager activation: `marchyo runtime restore` replays them.

### Toggles

`marchyo toggle <name>` flips a desktop feature on or off, live. The switches include
`gaps`, `transparency`, `animations`, `reduce-motion` (make shell transitions instant; takes `--apply`),
`fullscreen-desktop` (hide the bar and drop gaps, borders and rounding), `nightlight`, `waybar`, `touchpad`, `touchscreen`, `idle`,
`screensaver`, `notifications`, `suspend` and `caffeine` (keep the machine awake).
`waybar` shows or hides the shell top bar. With the shell running, `--status` for
`waybar` and `notifications` reads the live bar and do-not-disturb state.
Add `--status` to check one, or `--apply` to make it permanent:

```bash
marchyo toggle nightlight            # on/off now
marchyo toggle gaps off --apply      # and keep it that way
```

One more switch, `hybrid-gpu`, changes hardware configuration and has no live mode, so
it only works with `--apply` (for example `marchyo toggle hybrid-gpu on --apply`);
it persists `marchyo.graphics.prime.enable`. `reduce-motion --apply` persists
`marchyo.theme.appearance.reduceMotion`.

### Notifications, what changed, first-login setup

```bash
marchyo notify "Build done" "Open it" -g 󰄬 --exec xdg-open ./out   # click runs the command
marchyo notify "Deploy?" -u critical --action Yes ./deploy --action No true
marchyo whats-new [--json]   # NEWS entries you have not seen, and the last switch
marchyo setup [--json]       # the first-login checklist; "marchyo setup fix git" fixes one item
```

`marchyo notify` takes the same flags as omarchy's `omarchy-notification-send`. Its
`--exec` and `--action` commands run as argument lists, never through a shell, and
only for notifications sent by `marchyo notify` itself: each one carries a
one-time token that no other application can use. The program cannot start with a
dash, a command has at most 32 words of 4096 characters, and a button needs a
label. A glyph (`-g`) needs the token too. Open the panels with
`marchyo shell open whatsnew` and `marchyo shell open setup`; a notification does so
for you when NEWS changes and on your first login (`Super + Ctrl + U` and
`Super + Ctrl + H` toggle them).

### Shell plugins

```bash
marchyo plugin add <git-url>     # pin a plugin; a rebuild bakes it in
marchyo plugin list
marchyo plugin validate ~/src/my-plugin
```

`validate` runs the build's manifest checks on a checkout.

### Shell panels and bar

`marchyo shell` drives the running shell (`marchyo.shell.enable`). Hypridle, the
screensaver, the lock bind and your scripts use it; each call exits 1 with a hint when
the shell is not running, and prints the shell's reply (`--json`:
`{"function", "reply"}`).

```bash
marchyo shell toggle|open <panel>   # controlcenter, audio, network, power, monitor, notifications, ...
marchyo shell close [<panel>]       # the named panel, or whichever is open
marchyo shell launcher <mode>       # apps | emoji | clipboard
marchyo shell bar [on|off]          # the top bar
marchyo shell overview [on|off]     # the window overview
marchyo shell lock                  # also: lock-state, bar-state, dnd-state (print the state)
marchyo shell dnd [on|off]          # do not disturb
marchyo shell dismiss [--all]       # newest notification toast, or every toast
marchyo shell notify-keys           # control the toasts from the keyboard
marchyo shell gallery [section]     # every shell control in every state (for development)
marchyo shell reload                # reload the shell's QML in place
```

### Volume and brightness

```bash
marchyo volume up|down|mute [--mic]   # 5% steps, capped at 100%; --mic is the default source
marchyo brightness up|down            # 5% steps
```

With the shell running, the on-screen display shows the level.

### Capture

```bash
marchyo capture screenshot [--target area|active|output|screen] [--edit]
marchyo capture record [--audio none|desktop|mic]   # run again to stop
marchyo capture ocr        # select a region, copy the recognized text
marchyo capture color      # color picker, hex to clipboard
```

### Windows, monitors, language and network

```bash
marchyo window pop                 # float, centre and pin the focused tile (again to undo)
marchyo window close-all           # close every window
marchyo window tiled-fullscreen    # tiled fullscreen
marchyo zoom in|out|reset          # cursor zoom
marchyo monitor scale-cycle        # step the focused monitor's scale
marchyo monitor laptop-toggle      # laptop panel on/off
marchyo monitor clamshell on|off   # the lid handler
marchyo monitor save --nix         # print the current layout as a marchyo.monitors snippet
marchyo monitor reset              # forget the display panel's saved settings
marchyo monitor workspaces reset   # forget which workspace block each monitor owns
marchyo language [code|list]       # show or set the display language (--revert to undo)
marchyo network portal             # sign in to a captive portal and wait until online
```

### Menus, launching, and session

```bash
marchyo menu [route]         # the command menu, e.g. capture or appearance.theme
marchyo menu --tui           # the gum menu, for when the shell is down
marchyo keybindings          # searchable cheat sheet (also Super + K in the shell)
marchyo launch <app>         # launch an app detached from the terminal
marchyo focus-or-launch <class> [cmd...]   # focus a window of that class, or launch it
marchyo lock                 # also: logout, suspend, hibernate, reboot, shutdown
marchyo powerprofile set <p> # power-saver / balanced / performance
```

In a Hyprland session, `logout`, `reboot` and `shutdown` run in a short-lived user
unit (30 seconds at most) that closes every window, waits up to 2 seconds for the apps
to exit, then ends the session or reboots or powers off. `shutdown` holds a sleep,
idle and lid-switch inhibitor meanwhile.

`marchyo menu select` and `marchyo menu input` are a dmenu mode for scripts: the rows
come on stdin, the choice goes to stdout, and a cancel exits 1 (2 when the shell is
not reachable). **Trigger**, **Speed test** measures network (`speedtest-go`) or disk
(`fio`) speed. The menu entries come from `marchyo.menu.entries`; add your own in
`~/.config/marchyo/menu.local.json`.

### Utilities

```bash
marchyo reminder set|show|clear     # reminders on lightweight timers
marchyo info datetime|battery       # quick pop-up notifications
marchyo transcode [file] [--to mp4|webm|gif]
marchyo font list --kind ui         # families to pick from (mono | ui | all)
marchyo font set <family>           # switch the terminal font live
marchyo font set <family> --kind ui # switch the UI font (GTK and shell)
marchyo font current                # the active terminal font
marchyo dictation start|stop|toggle|status   # drive the configured dictation backend
marchyo share [paths...] [--to <alias|ip>] [--pin <pin>] [--clipboard]
```

`transcode` also takes `--ascii`, and `font list --format json` adds each family's
`kind` and the current fonts.

### Sharing with LocalSend

`marchyo share` speaks the [LocalSend](https://localsend.org) v2 protocol itself, so it
sends to phones and computers running LocalSend without opening the app:

- `marchyo share photo.jpg notes/` looks for LocalSend devices on the local network for
  about 2 seconds. With one device it sends straight away; with several it opens a
  picker (under `--no-input` it lists them and asks for `--to`). Folders are sent
  recursively and arrive with their structure.
- `--to <alias|ip>` picks the receiver by its LocalSend name or by IPv4 address
  (optionally `ip:port`), which skips discovery. Use it in scripts.
- `--pin <pin>` answers a receiver that asks for a PIN.
- `--clipboard` copies a file's contents (or a folder's path) to the clipboard with
  `wl-copy` instead of sending.
- With no paths, a menu picks a file, a folder, or the current clipboard text (sent as
  a LocalSend message).
- `--json` prints `{"share": {"peer": ..., "status": "sent", "sent": n, "skipped": n}}`.

The receiver has to accept the transfer; notifications report accepted, declined and
finished. Discovery uses UDP multicast on port 53317 and falls back to scanning the
local /24 subnet, so sending also works with `programs.localsend.openFirewall = false`.
`Share` is also listed under **Trigger** in `marchyo menu`.

### Managing the system

```bash
marchyo status               # current config + system info
marchyo rebuild              # rebuild against your flake
marchyo update               # update your flake inputs
marchyo update --check       # only report whether the lock pins a newer nixpkgs
marchyo upgrade              # update, then rebuild
marchyo rollback             # switch to the previous generation
marchyo gc                   # collect old generations (--delete-older-than 14d)
marchyo diff                 # what changed between generations
marchyo debug                # diagnostics bundle: versions, generation, journal errors
marchyo doctor               # session health checks
```

`rebuild`, `update`, `upgrade`, `rollback` and `diff` take `-n` for a dry run.
`doctor` prints PASS, FAIL or SKIP per check (the shell's baked tool paths exist,
Hyprland and shell IPC answer, the Marchyo user services are active) and exits 1 on
any FAIL.

The update and rollback commands are covered in more depth in
[Updating](./10-updating.md). You can also flip whole feature groups on and off —
`marchyo install development`, `marchyo remove media` — and add web-app windows with
`marchyo webapp add <url> [--name --key]` (`webapp rm <name>` removes one); those always
rebuild. `marchyo security enroll fido2|fingerprint` needs the matching
`marchyo.security.*` flag.

`marchyo plugin update` and `plugin remove <name>` complete the plugin commands above.
`marchyo runtime status` lists the active live overrides, and
`marchyo completion bash|zsh|fish|man` prints shell completions and the man page
(both are installed with the package).

## Text or JSON, quiet or loud

Most commands take `--format text|json` (or `--json`) if you want to script against
them, plus `--color`, `--no-color`, `--plain`, `--no-animation`, `--no-input`, `-q` for
quiet and `-v` for verbose. Data goes to standard output and diagnostics to standard
error, so piping works cleanly. Exit codes: 0 success, 1 runtime failure, 2 usage error.

## A stable contract

As of 1.0, the command names, arguments, and flags are frozen until 2.0 — new things
may be *added* in 1.x, but nothing you learn here will be renamed or removed under
you. You can build habits and scripts on it safely.
