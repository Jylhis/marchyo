# lazygit with jylhis/base16 colors. The gui.theme mapping mirrors the slot
# mapping the retired Stylix lazygit target used, so the re-home is a visual
# no-op: slots come from modules/generic/theme-slots.nix (Jylhis pair by
# variant, or marchyo.theme.scheme's catalog palette).
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
  config = {
    programs.lazygit = {
      enable = true;
      settings.gui.theme = lib.mkIf themeEnabled (
        with s;
        {
          activeBorderColor = [
            base0D
            "bold"
          ];
          inactiveBorderColor = [ base03 ];
          searchingActiveBorderColor = [
            base04
            "bold"
          ];
          optionsTextColor = [ base06 ];
          selectedLineBgColor = [ base03 ];
          cherryPickedCommitBgColor = [ base02 ];
          cherryPickedCommitFgColor = [ base03 ];
          unstagedChangesColor = [ base08 ];
          defaultFgColor = [ base05 ];
        }
      );
    };
  };
}
