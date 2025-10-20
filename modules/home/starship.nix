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
  config = mkIf (cfg != null && cfg.enable && colors != null) {
    programs.starship.settings = {
      palette = "base16";
      palettes.base16 = with colors; {
        # Base colors
        base00 = hex base00;
        base01 = hex base01;
        base02 = hex base02;
        base03 = hex base03;
        base04 = hex base04;
        base05 = hex base05;
        base06 = hex base06;
        base07 = hex base07;
        base08 = hex base08;
        base09 = hex base09;
        base0A = hex base0A;
        base0B = hex base0B;
        base0C = hex base0C;
        base0D = hex base0D;
        base0E = hex base0E;
        base0F = hex base0F;

        # Standard color names
        black = hex base00;
        red = hex base08;
        green = hex base0B;
        yellow = hex base0A;
        blue = hex base0D;
        magenta = hex base0E;
        cyan = hex base0C;
        white = hex base05;

        # Bright variants
        bright-black = hex base03;
        bright-red = hex base08;
        bright-green = hex base0B;
        bright-yellow = hex base0A;
        bright-blue = hex base0D;
        bright-magenta = hex base0E;
        bright-cyan = hex base0C;
        bright-white = hex base07;

        # Starship uses 'purple' instead of 'magenta'
        purple = hex base0E;
        bright-purple = hex base0E;
      };
    };
  };
}
