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
in
{
  config = {
    programs.fzf = {
      enable = true;
      colors = mkIf (cfg != null && cfg.enable && colors != null) (
        with colors;
        {
          "bg" = "#${base00}";
          "bg+" = "#${base01}";
          "fg" = "#${base04}";
          "fg+" = "#${base06}";
          "header" = "#${base0D}";
          "hl" = "#${base0D}";
          "hl+" = "#${base0D}";
          "info" = "#${base0A}";
          "marker" = "#${base0C}";
          "pointer" = "#${base0C}";
          "prompt" = "#${base0A}";
          "spinner" = "#${base0C}";
        }
      );
    };
  };
}
