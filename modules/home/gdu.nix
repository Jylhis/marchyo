# gdu (disk usage TUI) colors. Mirrors the retired Stylix gdu target's slot
# mapping (lib/theme-generators.nix gduText); slots come from
# modules/generic/theme-slots.nix (Jylhis pair by variant, or
# marchyo.theme.scheme's catalog palette). The binary ships in
# modules/nixos/packages.nix; this contributes only the user config, which
# carries nothing but the theme. On a Linux desktop the file links to the
# runtime theme layer's current-theme/gdu.yaml, read at each gdu start.
{
  config,
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  theme = (osConfig.marchyo or { }).theme or { };
  themeEnabled = theme.enable or true;
  runtimeThemed =
    pkgs.stdenv.hostPlatform.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  s = import ../generic/theme-slots.nix {
    inherit pkgs lib;
    variant = theme.variant or "dark";
    scheme = theme.scheme or null;
  };
  gen = import ../../lib/theme-generators.nix { inherit lib; };
in
{
  config = lib.mkIf themeEnabled {
    xdg.configFile."gdu/gdu.yaml" =
      if runtimeThemed then
        {
          source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/marchyo/current-theme/gdu.yaml";
        }
      else
        { text = gen.gduText s; };
  };
}
