---
name: marchyo-plugin
description: >
  Write, package and install a plugin for the marchyo shell (Quickshell). Use when
  the user wants a new bar widget, launcher provider or background daemon for the
  marchyo shell, asks how `mkMarchyoShellPlugin` or a plugin manifest works, adds a
  plugin with `marchyo plugin add`, or ports an omarchy plugin. Triggers:
  marchyo plugin, mkMarchyoShellPlugin, manifest.json, bar-widget, launcher
  plugin, shell/compat, omarchy plugin.
---

# Writing a marchyo shell plugin

Plugins are Nix-declared and baked into the store shell. Nothing is discovered at
runtime and there is no hot reload: a change needs a rebuild. The build checks the
manifest, so a wrong plugin fails at build time with a message that names the rule.

## Layout

A plugin is a directory (usually a git repository) with a `manifest.json` at its
root and the QML files it names. No symlinks are allowed anywhere inside.

```json
{
  "schemaVersion": 1,
  "id": "acme.weather",
  "name": "Weather",
  "version": "1.0.0",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "BarWidget.qml" }
}
```

- `id` is `<author>.<name>`. The `marchyo.` and `omarchy.` namespaces are reserved
  for first-party surfaces. Ids are unique across the shell.
- `kinds` is a closed set: `bar-widget`, `launcher`, `daemon`, `bar`, `panel`,
  `menu`, `overlay`, `service` (`packages/marchyo-shell/plugin-kinds.nix`).
- Optional: `keepLoaded: true` (mount a panel, menu or overlay at shell start),
  the `barWidget` block (`displayName`, `category`, `allowMultiple`,
  `defaultSection`, `defaults`, `schema`, `settingsForm`), and sibling
  `*.manifest.json` files for extra widgets in the same repo.
- Optional: `replaces`, the native roles the plugin takes over
  (`packages/marchyo-shell/native-roles.nix`): `panel.<id>` (audio, network, power, monitor, display, weather, agents, elsewhen, tailscale, wifiqr, bluetooth, speedtest, dropbox, gallery), `polkit`, `launcher`, `launcher.emoji` and `launcher.clipboard`.
  Pass the same list to `mkMarchyoShellPlugin`. One plugin per role. A replacing
  bar-widget plugin must be in `bar.layout`, because it opens from its live widget.
- `entryPoints` has exactly one key per kind, mapping to a relative file that
  exists. No absolute paths and no `..`.

Kinds and their entry point keys:

- `bar-widget`, key `barWidget`: a bar item. Place it by manifest id in
  `marchyo.shell.settings.bar.layout`.
- `launcher`, key `launcher`: a `qs.Launcher` `Provider`. The manifest also needs
  a `prefix`, the query prefix that routes the apps palette to it. It must be
  non-empty, contain no whitespace, and must not start with `=`, `>`, `#` or `!`,
  which the first-party providers use.
- `daemon`, key `daemon`: a non-visual `Item` or `QtObject`, instantiated once at
  the shell root.
- `panel`, `menu`, `overlay` (keys of the same name): an `Item` with
  `open(payloadJson)` and `close()` that owns its window. It loads when summoned
  (`omarchy-shell shell summon <id>`, or `marchyo shell` IPC `summonPlugin`) and,
  with `keepLoaded`, at start. The host injects `shell` (a `PluginShellApi`),
  `manifest`, `omarchyPath`, `service` and the registries, for the properties the
  item declares.
- `service`: a headless singleton created at shell start; a panel of the same
  plugin reads it as `service`.
- `bar`: a full bar that replaces the built-in one when named in
  `marchyo.shell.barPlugin`.

A launcher or daemon whose QML fails to load is logged with `console.warn` and
skipped. Example plugins for each kind are in `tests/eval/fixtures/` in the
marchyo repo.

## Package it

```nix
pkgs.mkMarchyoShellPlugin {
  src = pkgs.fetchgit {
    url = "https://example.com/acme-weather.git";
    rev = "...";
    hash = "sha256-...";
  };
  id = "acme.weather";
  name = "Weather";
  kinds = [ "bar-widget" ];
  entryPoints.barWidget = "BarWidget.qml";
  # prefix = "w";  # launcher kind only
}
```

The `id`, `kinds`, `entryPoints` and `prefix` arguments must equal the manifest
(`packages/marchyo-shell/plugin.nix` checks it). They are repeated in Nix so the
shell index is generated without reading files at evaluation time.

## Install it

Declare it in the NixOS configuration, then rebuild:

```nix
marchyo.shell.plugins = [ (pkgs.mkMarchyoShellPlugin { /* as above */ }) ];
marchyo.shell.settings.bar.layout.right = [ { id = "acme.weather"; } ];
```

Or pin a git URL with the CLI, which records it under `marchyo.shell.extraPlugins`
and bakes it in on rebuild:

```bash
marchyo plugin add https://example.com/acme-weather.git
marchyo plugin list
marchyo plugin update [id]
marchyo plugin remove <id>
```

Every build writes `share/marchyo/shell/plugins.lock.json` with each plugin's id,
kinds, entry points and store path. `marchyo doctor` reports plugins that did not
load.

## QML conventions

- Import the shell's API: `import qs.Commons` for `Style`, `Colors` and `Theme`
  tokens, `import qs.Ui` for the widget kit. Take colours and spacing from the
  tokens so the plugin follows runtime theme switches. Never hard-code hex values.
- Keep state in the plugin's own objects. A bar widget is instantiated once per
  monitor, so a process, timer or socket belongs in a `daemon` plugin or a
  singleton, not in the widget.
- Run commands with `Quickshell.Io.Process` and avoid blocking the UI thread.

## Omarchy plugins

`shell/compat/` provides omarchy's plugin host API (`qs.compat.Ui` and
`qs.compat.Commons`) so imported omarchy bar widgets run nearly unmodified. The
build rewrites `import qs.Ui` and `import qs.Commons` to the compat namespaces and
bare `Color.` reads to `CompatColor.`. The compat files are the one place omarchy
code is copied verbatim (MIT, with a provenance revision in
`shell/compat/README.md`). To use one, wrap its repository with
`mkMarchyoShellPlugin` and a manifest that declares it as a `bar-widget`; see
`marchyo-shell-plugins` in `overlay.nix` for working examples.

## Develop without a rebuild

On a development host set `marchyo.shell.devPlugins.enable = true` and rebuild
once. Then `marchyo plugin validate <dir>` checks a checkout, and
`marchyo plugin dev <dir> [--watch]` syncs a rewritten copy into
`$XDG_STATE_HOME/marchyo/shell/dev-plugins` and reloads the shell. Only the
`bar-widget`, `panel`, `overlay`, `menu` and `launcher` kinds load this way. Dev
plugins are unreviewed code running unsandboxed in the shell; never enable the
loader on a host you do not develop on.

## Check

- `nix build` the plugin derivation: the manifest checks run in its build phase.
- Evaluate the host with the plugin in `marchyo.shell.plugins`.
- In a live session, `marchyo shell reload` reloads QML from the baked shell
  after the user activates the rebuilt system.
