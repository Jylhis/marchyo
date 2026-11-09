# Writes the command menu tree (marchyo.menu.entries) for the shell. The user
# overlay ~/.config/marchyo/menu.local.json is merged by the shell at runtime,
# which also writes the merged tree as omarchy's menu extension while
# omarchy.menu replaces the launcher (shell/Plugins/OmarchyMenuFeed.qml).
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && (osConfig.marchyo.desktop.enable or false);
  entries = osConfig.marchyo.menu.entries or { };
in
{
  config = lib.mkIf desktopEnabled {
    xdg.configFile."marchyo/menu.json".text = builtins.toJSON entries;
  };
}
