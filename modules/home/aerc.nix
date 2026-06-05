# Per-user aerc (TUI mail client).
#
# Enabled via Home-Manager's programs.aerc when it is the selected
# marchyo.defaults.email and desktop is enabled. xdg.nix routes mailto: links
# to aerc.desktop. Account/credential setup (accounts.email.accounts.<name>)
# is left to the consumer.
{
  osConfig ? { },
  lib,
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };
  enabled = (osConfig.marchyo.desktop.enable or false) && (defaults.email or null) == "aerc";
in
{
  config = lib.mkIf enabled {
    programs.aerc.enable = true;
  };
}
