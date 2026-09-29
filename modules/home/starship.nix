# Starship prompt with the Jylhis design preset. Split out of jylhis-theme.nix
# (Linux-gated) so the prompt works on darwin too. The upstream jylhis-design
# starship target stays disabled there so starship.toml is only written here.
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
