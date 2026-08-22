# shell/ — the marchyo Quickshell shell

A custom [Quickshell](https://quickshell.org) desktop shell: a single
long-running QML process that will eventually replace today's discrete
waybar + mako + swayosd + vicinae composition (bar, panels, OSD,
notifications, lock). Design and roadmap: **[../plans/shell.md](../plans/shell.md)**.

## Status — Phase 0 (packaging spike)

A minimal Jylhis-themed top bar with a live clock, proving the Nix path
(package → autostart → QML-from-store) and the tokens→QML theming bridge.
Gated behind `marchyo.shell.enable` (default off); does not touch the
discrete stack. The plugin registry and IPC architecture land in Phase 1.

Layout:

```
shell/
  shell.qml           ShellRoot entry point (the themed bar)
  Commons/
    qmldir            declares the qs.Commons module
    Color.qml         Jylhis design-token color singleton (Field defaults;
                      the Nix build regenerates it for the host theme variant)
```

## Development

Run the tree directly for a fast QML iteration loop (no rebuild):

```bash
quickshell -p shell          # from the repo root
# or, the wrapped, theme-baked package:
nix run .#marchyo-shell
```
