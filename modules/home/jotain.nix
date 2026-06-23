# Per-user jotain (Jylhis's Emacs config) as the marchyo default editor.
#
# Enabled via services.jotain when "jotain" is the selected
# marchyo.defaults.editor and/or terminalEditor and desktop is enabled.
# EDITOR/VISUAL are owned by marchyo at the NixOS level
# (modules/nixos/defaults.nix maps jotain -> jotain-visual/jotain-editor), so
# defaultEditor is false here to avoid double-defining the session variables;
# this also keeps the mixed case correct (e.g. editor = "jotain" +
# terminalEditor = "neovim"). xdg.nix routes text/plain to jotain-client.desktop.
{
  osConfig ? { },
  pkgs,
  lib,
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };
  selected = (defaults.editor or null) == "jotain" || (defaults.terminalEditor or null) == "jotain";
  enabled = pkgs.stdenv.isLinux && (osConfig.marchyo.desktop.enable or false) && selected;
in
{
  config = lib.mkIf enabled {
    services.jotain = {
      enable = true;
      defaultEditor = false; # marchyo owns EDITOR/VISUAL (modules/nixos/defaults.nix)
      client.enable = true; # installs jotain-client.desktop (Linux)
    };
  };
}
