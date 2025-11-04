{
  lib,
  config,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf;
  hasOsConfig = osConfig != { } && osConfig ? marchyo;
  cfg = if hasOsConfig then osConfig.marchyo.theme else null;
  colors = if config ? colorScheme then config.colorScheme.palette else null;

  # Helper to convert hex to rgb() format
  toRgb =
    color:
    let
      inherit (lib.strings) substring;
      # Convert hex digit to decimal
      hexToDec =
        hex:
        let
          values = {
            "0" = 0;
            "1" = 1;
            "2" = 2;
            "3" = 3;
            "4" = 4;
            "5" = 5;
            "6" = 6;
            "7" = 7;
            "8" = 8;
            "9" = 9;
            "a" = 10;
            "b" = 11;
            "c" = 12;
            "d" = 13;
            "e" = 14;
            "f" = 15;
            "A" = 10;
            "B" = 11;
            "C" = 12;
            "D" = 13;
            "E" = 14;
            "F" = 15;
          };
        in
        values.${hex};
      # Convert 2-digit hex to decimal
      hex2ToDec =
        hex:
        let
          high = substring 0 1 hex;
          low = substring 1 1 hex;
        in
        (hexToDec high) * 16 + (hexToDec low);
      r = hex2ToDec (substring 0 2 color);
      g = hex2ToDec (substring 2 2 color);
      b = hex2ToDec (substring 4 2 color);
    in
    "rgb(${toString r}, ${toString g}, ${toString b})";
in
{
  config = mkIf (cfg != null && cfg.enable && colors != null) {
    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          disable_loading_bar = true;
          grace = 10;
          hide_cursor = true;
          ignore_empty_input = true;
          no_fade_in = false;
          no_fade_out = false;
        };

        animations = {
          enabled = true;
        };

        auth = {
          "fingerprint:enabled" = true;
        };

        background = [
          {
            path = "screenshot";
            blur_passes = 3;
            blur_size = 8;
            noise = 0.0117;
            contrast = 0.8916;
            brightness = 0.8172;
            vibrancy = 0.1696;
            vibrancy_darkness = 0.0;
          }
        ];

        label = {
          monitor = "";
          text = "\$FPRINTPROMPT";
          text_align = "center";
          color = toRgb colors.base05;
          font_size = 24;
          font_family = "CaskaydiaMono Nerd Font";
          position = "0, -100";
          halign = "center";
          valign = "center";
        };

        input-field = {
          monitor = "";
          size = "600, 100";
          position = "0, 0";
          halign = "center";
          valign = "center";

          inner_color = toRgb colors.base00;
          outer_color = toRgb colors.base0D;
          outline_thickness = 4;

          font_family = "CaskaydiaMono Nerd Font";
          font_size = 32;
          font_color = toRgb colors.base05;

          placeholder_color = toRgb colors.base04;
          placeholder_text = "  Enter Password 󰈷";
          check_color = toRgb colors.base0B;
          fail_color = toRgb colors.base08;
          fail_text = "<i>\$PAMFAIL (\$ATTEMPTS)</i>";

          rounding = 0;
          shadow_passes = 0;
          fade_on_empty = false;
        };
      };
    };
  };
}
