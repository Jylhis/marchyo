# greeter/ — the marchyo greetd greeter

A [Quickshell](https://quickshell.org) config that replaces tuigreet as the
greetd greeter. greetd runs it inside [cage](https://github.com/cage-kiosk/cage)
(`modules/nixos/boot.nix`); it authenticates through Quickshell's native
greetd client (`Quickshell.Services.Greetd`) and launches
`uwsm start hyprland-uwsm.desktop` — the same session command tuigreet ran.

Single-file design: `shell.qml` holds the whole state machine (createSession →
authMessage → respond → readyToLaunch → launch) on the root object, so the
surface is a pure view — the same rule the bar follows (`../shell/README.md`).
The surface is a `FloatingWindow` (a plain xdg-toplevel) that cage fullscreens,
not a layer-shell `PanelWindow`: cage has no wlr-layer-shell support, so a layer
surface never maps and the screen stays black (the regreet-under-cage shape).
Under multi-monitor cage (`-m extend`) the window spans the union of outputs;
the clock/card column and the power buttons are positioned against the primary
(first) output's geometry so the login card sits centered on one monitor
instead of straddling the bezel gap.
`Commons/` holds dev-default singletons
(palette copies from `../shell/Commons/` plus a greeter `Config.qml`); the Nix
build (`../packages/marchyo-shell/package.nix`) regenerates them with the
host's theme variant and store-baked tool paths, and wraps the entry point as
`marchyo-greeter`.

Parity with the tuigreet config it replaces: last-user prefill
(`/var/cache/marchyo-greeter/last-user`, written on successful auth),
password masking, power controls (reboot / power off). Deliberately not
ported: the user menu (marchyo hosts are single-user; the prefill covers it)
and session picking (the session was already forced to Hyprland via uwsm).

UX patterns (adopted from the Cozytile SDDM greeter,
github.com/Darkkal44/Cozytile, reimplemented — nothing vendored; that repo
has no license):

- Scale-factor layout: all greeter geometry derives from `s = height / 1080`,
  so the card renders correctly on HiDPI/4K cage outputs instead of assuming
  1080p pixels. The geometry lives on the `FloatingWindow` (the one object
  that knows the real output size), not in `Commons/Style.qml` (bar geometry
  there is fontScale-scaled and would double-scale).
- Entrance: the clock/card column fades and rises in once when the window
  maps (a one-shot `NumberAnimation`, never a binding, so it cannot
  re-trigger on resize).
- Failed-auth shake: `onAuthFailure` nudges the card horizontally via a
  `Translate` transform — a transform, not `x`, so the card keeps its
  `horizontalCenter` anchor and the animation never fights it.
- Accent caret: the secret field's native cursor is hidden and a blinking
  accent-colored bar tracks `cursorRectangle`, so the caret carries the
  theme accent.

Dev run (on a Wayland desktop, outside greetd the UI shows
"greetd socket unavailable"):

    TZDIR=/etc/zoneinfo quickshell -p greeter
