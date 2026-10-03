# gdu (disk usage TUI) colors. Mirrors the retired Stylix gdu target's slot
# mapping; slots come from modules/generic/theme-slots.nix (Jylhis pair by
# variant, or marchyo.theme.scheme's catalog palette). The binary ships in
# modules/nixos/packages.nix; this contributes only the user config.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  theme = (osConfig.marchyo or { }).theme or { };
  themeEnabled = theme.enable or true;
  s = import ../generic/theme-slots.nix {
    inherit pkgs lib;
    variant = theme.variant or "dark";
    scheme = theme.scheme or null;
  };
in
{
  config = lib.mkIf themeEnabled {
    xdg.configFile."gdu/gdu.yaml".text = with s; ''
      style:
        selected-row:
          text-color: "${base05}"
          background-color: "${base00}"
        result-row:
          number-color: "${base06}"
          directory-color: "${base02}"
        footer:
          text-color: "${base05}"
          background-color: "${base00}"
          number-color: "${base06}"
        header:
          text-color: "${base05}"
          background-color: "${base00}"
    '';
  };
}
