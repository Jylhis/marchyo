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
  fast, reversible, low-stakes. A live change resets on the next full rebuild.
- **`--apply` makes it stick.** Add this flag and the change is also written down and
  rebuilt into your system, so it survives reboots. Your hand-written configuration
  still wins if it disagrees — `--apply` sets a default, not an override.
- **`--revert` undoes it.** Drops the live change, puts the declared value back, and
  cleans up anything `--apply` persisted.

So the rhythm is: try it live, and if you love it, run the same command with
`--apply`. A few commands (`install`, `remove`, `webapp`) always rebuild,
because there's no meaningful "live" version of installing software.
`security enroll` only registers your fingerprint or key; turn the feature on
in your config first.

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
marchyo theme bar-position bottom
marchyo theme bar-background glassy
marchyo bar put marchyo.cpu centerBegin   # edit the bar layout live (marchyo bar --help)
marchyo theme icons          # installed icon themes; give a name to set one
```

Runtime changes survive a home-manager activation: `marchyo runtime restore` replays them.

### Toggles

`marchyo toggle <name>` flips a desktop feature on or off, live. The switches include
`gaps`, `transparency`, `animations`, `reduce-motion` (make shell transitions instant; takes `--apply`),
`nightlight`, `waybar`, `touchpad`, `touchscreen`, `idle`,
`screensaver`, `notifications`, `suspend`, `caffeine` (keep the machine awake), and
`crash-capture` (the crash notifications, see [Crash diagnosis](#crash-diagnosis)).
`waybar` shows or hides the shell top bar.
Add `--status` to check one, or `--apply` to make it permanent:

```bash
marchyo toggle nightlight            # on/off now
marchyo toggle gaps off --apply      # and keep it that way
```

One more switch, `hybrid-gpu`, changes hardware configuration and has no live mode, so
it only works with `--apply` (for example `marchyo toggle hybrid-gpu on --apply`).

### Crash diagnosis

When a program of yours dumps core, a notification offers **Diagnose**. The action
runs `marchyo agent crash <pid>`, which starts your default AI agent (`$AI_AGENT`) in
a terminal with the `diagnose-crash` skill, in its most restricted approval mode and
in its own transient unit. The crash values reach the agent quoted and marked as
untrusted. You can also run it by hand against any PID from `coredumpctl list`. The watcher is on while a desktop and an AI agent are
installed. Silence it for the session with `marchyo toggle crash-capture off`, or for
good with `marchyo.ai.crashCapture.enable = false`; `marchyo.ai.crashCapture.ignore`
skips programs by name.

The same agents get the `marchyo`, `marchyo-plugin` and `diagnose-crash` skills in
their skill directories (`marchyo.ai.skills.enable`).

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

### Capture

```bash
marchyo capture screenshot [--target area|active|output|screen] [--edit]
marchyo capture record [--audio none|desktop|mic]   # run again to stop
marchyo capture ocr        # select a region, copy the recognized text
marchyo capture color      # color picker, hex to clipboard
```

### Menus, launching, and session

```bash
marchyo menu [route]         # the command menu, e.g. capture or appearance.theme
marchyo menu --tui           # the gum menu, for when the shell is down
marchyo keybindings          # searchable cheat sheet (also Super + K in the shell)
marchyo launch <app>         # launch an app detached from the terminal
marchyo lock                 # also: logout, suspend, hibernate, reboot, shutdown
marchyo powerprofile set <p> # power-saver / balanced / performance
```

`marchyo menu select` and `marchyo menu input` are a dmenu mode for scripts: the rows
come on stdin, the choice goes to stdout, and a cancel exits 1 (2 when the shell is
not reachable). The menu entries come from `marchyo.menu.entries`; add your own in
`~/.config/marchyo/menu.local.json`.

### Utilities

```bash
marchyo reminder set|show|clear     # reminders on lightweight timers
marchyo info datetime|battery       # quick pop-up notifications
marchyo transcode [file] [--to mp4|webm|gif]
marchyo font list --kind ui         # families to pick from (mono | ui | all)
marchyo font set <family>           # switch the terminal font live
marchyo font set <family> --kind ui # switch the UI font (GTK and shell)
```

### Project dev environments

```bash
marchyo dev init <lang>      # write devenv.nix, devenv.yaml and .envrc here
marchyo dev db <engine>      # add a devenv database service to devenv.nix
```

`dev init` knows go, rust, python, node, bun, deno, ruby, elixir, java, zig, php, dotnet,
ocaml, clojure and scala. It refuses to replace existing files unless you pass `--force`.
`dev db` takes postgres, mysql, mariadb, redis or mongodb, can be repeated safely, and
leaves a `devenv.nix` of an unexpected shape untouched.

### Managing the system

```bash
marchyo status               # current config + system info
marchyo rebuild              # rebuild against your flake
marchyo update               # update your flake inputs
marchyo upgrade              # update, then rebuild
marchyo rollback             # switch to the previous generation
marchyo gc                   # collect old generations
marchyo diff                 # what changed between generations
```

The update and rollback commands are covered in more depth in
[Updating](./10-updating.md). You can also flip whole feature groups on and off —
`marchyo install development`, `marchyo remove media` — and add web-app windows with
`marchyo webapp add <url>`; those always rebuild.

## Text or JSON, quiet or loud

Most commands take `--format text|json` (or `--json`) if you want to script against
them, plus `--plain`, `--no-color`, `-q` for quiet and `-v` for verbose. Data goes to
standard output and diagnostics to standard error, so piping works cleanly.

## A stable contract

As of 1.0, the command names, arguments, and flags are frozen until 2.0 — new things
may be *added* in 1.x, but nothing you learn here will be renamed or removed under
you. You can build habits and scripts on it safely.
