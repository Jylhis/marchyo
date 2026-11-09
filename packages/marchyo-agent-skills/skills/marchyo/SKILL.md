---
name: marchyo
description: >
  Work on a Marchyo NixOS desktop: the `marchyo` CLI, runtime and declarative
  theming, Hyprland keybinds, the Quickshell shell and its plugins, and the
  `marchyo.*` options. Use when the user asks to change the theme, wallpaper,
  keybinds, bar, panels, toggles, display language or monitors on a Marchyo
  system, asks what a `marchyo` command does, or edits a configuration that
  imports marchyo. Triggers: marchyo, marchyo-shell, Super+Space, theme set,
  keybindings, marchyo.* option.
---

# Marchyo

Marchyo is a NixOS and Home Manager configuration layer with a Hyprland desktop,
a Quickshell shell and a `marchyo` CLI. Every option lives under `marchyo.*`.

## Declarative first

Never suggest imperative changes (`nix-env -i`, editing dotfiles in `$HOME`,
`systemctl enable`). The durable change is an edit to the user's flake or module
followed by a rebuild: `marchyo rebuild` (or `nixos-rebuild switch --flake`).
Never run a switch yourself unless the user asks. Many `marchyo` commands change
only the running session; they reset on the next activation unless you pass
`--apply` or set the matching option.

Find the configuration with `marchyo status`. Option names and defaults are in
the module sources (`modules/nixos/options/*.nix` in the marchyo repo) and in
`nix eval` on the host: `nixos-option marchyo.theme.variant`.

## The CLI

`marchyo --help` lists everything; `marchyo <group> --help` has examples. Add
`--json` for machine-readable output on any command.

- Inspect: `status`, `doctor` (session health), `debug` (diagnostics bundle),
  `diff` (generations), `info`.
- System: `rebuild`, `update`, `upgrade`, `rollback`, `gc`.
- Look and feel: `theme`, `bg`, `font`, `toggle`, `monitor`, `language`.
- Shell: `shell toggle|open|close <panel>`, `shell launcher <mode>`,
  `shell bar`, `shell dnd`, `shell overview`, `shell reload`, `menu`.
- Capture: `capture` (screenshots, recording, OCR, colour picker).
- Agents: `agent usage` (limits and tokens), `agent account` (several sign-ins),
  `agent crash <pid>` (diagnose a crash).
- Plugins: `plugin add|list|update|remove`.

## Theming

The build-time source of truth is `marchyo.theme.variant` (`dark` or `light`)
and `marchyo.theme.scheme` (a named scheme). Every theme in
`marchyo.theme.themes` is also materialised as a runtime theme directory, so
the CLI can switch without a rebuild:

```bash
marchyo theme list
marchyo theme get
marchyo theme set <name>            # live; resets on the next activation
marchyo theme set <name> --apply    # also persist through a rebuild
marchyo theme next
marchyo theme generate <image>      # palette from a wallpaper (matugen)
marchyo bg set <image>              # wallpaper only
```

A runtime switch recolours the shell, terminal, Hyprland borders, wallpaper,
GTK/Qt, bat, fzf, starship, hyprlock and other emitters
(`modules/home/theme-runtime.nix`). A new themed surface must be emitted in three
places: the Jylhis pair in `theme-runtime.nix`, its `mkSchemeThemeDir`, and the
CLI `generateThemeChangeBase`. Colours come from palette tokens, never from
hard-coded hex values.

## Keybinds

Every shipped bind is one entry in `lib/keybinds.nix`, rendered into Hyprland by
`modules/home/keybinds.nix`. Entries carry `combo`, `description`, `group` and an
`action`. The layout follows planes: Super for the system, Super+Shift for apps,
Super+Ctrl for panels and menus, Super+Ctrl+Alt for quick actions.
`marchyo.keyboard.legacyBinds = true` restores the earlier chords.

- Search the live binds: `Super+K`, or `marchyo keybindings`.
- To add a bind, add an entry to the table (or, in a user configuration, extend
  `wayland.windowManager.hyprland.settings`). Do not edit generated files under
  `~/.config/hypr`.
- A new panel needs a `shortcuts.json` entry, a `lib/keybinds.nix` entry, a
  `marchyo shell` verb and a `doctor` check together.

## Hyprland

Hyprland is configured in Lua through Home Manager
(`wayland.windowManager.hyprland.settings`, rendered by `lib/hyprland-lua.nix`).
Query the running session with `hyprctl` (`hyprctl clients -j`,
`hyprctl monitors -j`). Monitors are an option (`marchyo.monitors`); change them
there, and use `marchyo monitor` only for runtime helpers such as scale cycling.

## The shell and its plugins

`marchyo-shell` is Quickshell QML under `shell/`. Panels are driven over IPC by
`marchyo shell`. State lives in `Services/` singletons; `Bar/` widgets are
instantiated per monitor, so never put seat-global state in them. Plugins are
Nix-declared and baked into the store shell. For writing one, use the
`marchyo-plugin` skill.

## Previewing shell changes

In the marchyo source tree (`lib/marchyo`), `shell/dev/shot` renders a surface of
`shell/` in a nested Hyprland sandbox. It does not touch the installed system. Run
it from `devenv shell`:

```bash
shell/dev/shot launcher                        # launcher[:MODE], default apps
shell/dev/shot menu:system                     # menu[:ROUTE]
shell/dev/shot panel:power                     # panel:ID
shell/dev/shot overview
shell/dev/shot screen                          # the whole SHOT output
shell/dev/shot launcher --state query=fire     # --state query=TEXT, select=INDEX
shell/dev/shot osd --ipc 'shell osdShow Volume 40 true'
shell/dev/shot launcher --grab                 # the card alone, with alpha
```

- `--ipc CALL` runs one IPC call first, for a surface name that `dev surfaces` lists.
- Without `--grab` the PNG is cropped from the composited output, so blur and shadows show.
- PNGs go to `~/.cache/marchyo-shell-sandbox/<surface>.png` unless `--out` is given.
  The MCP `screenshot` tool writes under `$TMPDIR/marchyo-shell-mcp/`.
- The `marchyo-shell` MCP server offers `sandbox_up`, `sandbox_down`, `sandbox_status`,
  `ipc_call`, `ipc_show`, `screenshot`, `logs` and `reload`. Register it once from
  `lib/marchyo` with `claude mcp add marchyo-shell -- go -C shell/dev/mcp run . -root ../../..`.
- Stop the sandbox with `shell/dev/sandbox down`.

## Runtime toggles

`marchyo toggle <name> [on|off]` flips gaps, transparency, animations,
nightlight, bar, touchpad, idle lock, screensaver, notifications, caffeine and
crash capture live. `--status` prints the state, `--apply` persists it.

## Checking your work

- Evaluate: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
  (or `nix flake check --no-build`). Only the user activates a system.
- Format: `nix fmt`. Lint Nix with statix and deadnix.
- Options need a `tests/eval/*.nix` `testNixOS` test and a page under
  `site/src/content/docs/docs/configuration/` in the marchyo repo.
