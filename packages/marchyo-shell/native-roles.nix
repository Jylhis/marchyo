# The closed set of native shell roles a plugin may replace through its
# manifest `replaces` list. Pure data with no arguments, so plugin.nix and the
# option declarations in modules/nixos/options/shell.nix both import it.
# `panel.<id>` is a summonable panel (shell/Services/PanelManager.qml); the
# `launcher*` roles are gated by the launcher, not by PanelManager.
[
  "panel.audio"
  "panel.network"
  "panel.power"
  "panel.monitor"
  "panel.display"
  "panel.weather"
  "panel.agents"
  "panel.elsewhen"
  "panel.tailscale"
  "panel.wifiqr"
  "panel.bluetooth"
  "panel.speedtest"
  "panel.dropbox"
  "panel.gallery"
  "polkit"
  "launcher"
  "launcher.emoji"
  "launcher.clipboard"
]
