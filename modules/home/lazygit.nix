{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = if osConfig ? marchyo then osConfig.marchyo.theme else null;
  colors = if config ? colorScheme then config.colorScheme.palette else null;
  hex = color: "#${color}";
in
{
  config = {
    programs.lazygit = {
      enable = true;
      settings = mkIf (cfg != null && cfg.enable && colors != null) {
        gui = {
          theme = {
            activeBorderColor = [
              (hex colors.base0D)
              "bold"
            ];
            inactiveBorderColor = [ (hex colors.base03) ];
            searchingActiveBorderColor = [
              (hex colors.base0A)
              "bold"
            ];
            optionsTextColor = [ (hex colors.base0D) ];
            selectedLineBgColor = [ (hex colors.base02) ];
            cherryPickedCommitBgColor = [ (hex colors.base0C) ];
            cherryPickedCommitFgColor = [ (hex colors.base0D) ];
            unstagedChangesColor = [ (hex colors.base08) ];
            defaultFgColor = [ (hex colors.base05) ];
          };
        };
      };
    };
  };
}
