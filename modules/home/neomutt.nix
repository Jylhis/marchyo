# Per-user NeoMutt (TUI mail client), enabled when it is the selected
# marchyo.defaults.email. xdg.nix routes mailto: links to neomutt.desktop;
# account/credential setup is left to the consumer.
{
  osConfig ? { },
  lib,
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };
  enabled = (osConfig.marchyo.desktop.enable or false) && (defaults.email or null) == "neomutt";
in
{
  config = lib.mkIf enabled {
    programs.neomutt.enable = true;
  };
}
