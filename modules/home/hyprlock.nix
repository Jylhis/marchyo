{
  lib,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf;
  hasOsConfig = osConfig != { } && osConfig ? marchyo;
  cfg = if hasOsConfig then osConfig.marchyo.theme else null;
in
{
  config = {
    programs.hyprlock = {
      enable = true;
      settings = mkIf (cfg != null && cfg.enable) {
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

        label = {
          monitor = "";
          text = "\$FPRINTPROMPT";
          text_align = "center";
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

          outline_thickness = 4;

          font_family = "CaskaydiaMono Nerd Font";
          font_size = 32;

          placeholder_text = "  Enter Password 󰈷";
          fail_text = "<i>\$PAMFAIL (\$ATTEMPTS)</i>";

          rounding = 0;
          shadow_passes = 0;
          fade_on_empty = false;
        };
      };
    };
  };
}
