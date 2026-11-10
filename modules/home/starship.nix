# Starship prompt with the Jylhis design preset. Split out of jylhis-theme.nix
# (Linux-gated). starship.toml comes from the vendored design files.
{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  themeEnabled = osConfig.marchyo.theme.enable;
in
{
  config = lib.mkIf themeEnabled {
    programs.starship.enable = lib.mkDefault true;
    xdg.configFile."starship.toml".source = "${pkgs.jylhis-design-src}/platforms/shell/starship.toml";
  };
}
