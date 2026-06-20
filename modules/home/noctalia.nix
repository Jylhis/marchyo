{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
in
{
  config = lib.mkIf desktopEnabled {
    programs.noctalia.enable = lib.mkDefault true;
  };
}
