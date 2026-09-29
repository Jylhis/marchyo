# omarchy plugin compat shim (`qs.compat.Ui` / `qs.compat.Commons`)

marchyo's shell has its own `qs.Ui` / `qs.Commons` API. Upstream *omarchy*
plugins are written against omarchy's "Quattro" shell host API, which is
different. This directory provides that host API under a separate QML namespace
so imported omarchy bar widgets run near-unmodified: only their
`import qs.Ui` / `import qs.Commons` lines are rewritten to
`qs.compat.Ui` / `qs.compat.Commons` (plugins at bake time in
`packages/marchyo-shell/package.nix`; the vendored files below at author time).

## Contents

- `Ui/` — Quattro host types vendored **verbatim** from omacom/omarchy
  (BarWidget, Panel, PanelController, PanelKeyCatcher, WidgetButton,
  BarIconButton, OpticalGlyph, PluginBarApi, KeyboardPanel, BorderSurface) plus
  a minimal `BorderOverlay` stub.
- `Commons/` — `ShellIpc` / `IpcRegistry` vendored verbatim; `Style`,
  `Color`, `Border`, `Util` **reimplemented** to expose omarchy's API backed
  by marchyo's own `qs.Commons` `Style`/`Color`/`Theme` tokens.

## Provenance

Vendored from **omacom/omarchy @ branch `quattro`**, MIT
(rev `b421b1b479ee9ea0863792282eee4ffeb50923dc`). Upstream licence:
`LICENSE.omarchy`. Re-sync if the upstream plugin host API changes.
