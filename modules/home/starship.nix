# Starship prompt with the Jylhis design preset.
#
# Factored out of jylhis-theme.nix (which is Linux-gated for GTK/Wayland
# assets) so the prompt works on darwin too: auto-discovered on Linux via
# modules/home/default.nix, imported explicitly by modules/darwin/home.nix.
# The upstream jylhis-design starship target stays disabled in
# jylhis-theme.nix so starship.toml is only written here.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  themeEnabled = (osConfig.marchyo or { }).theme.enable or true;
in
{
  config = lib.mkIf themeEnabled {
    programs.starship.enable = lib.mkDefault true;
    xdg.configFile."starship.toml".source = "${pkgs.jylhis-design-src}/platforms/shell/starship.toml";
  };
}
