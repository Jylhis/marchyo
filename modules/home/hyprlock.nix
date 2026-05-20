{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf;
  hasOsConfig = osConfig != { } && osConfig ? marchyo;
  cfg = if hasOsConfig then osConfig.marchyo.theme else null;

  themeVariant = if cfg != null then cfg.variant else "dark";
  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    variant = themeVariant;
  };

  hexNoHash = lib.removePrefix "#";
  rgba = h: a: "rgba(${hexNoHash h}${a})";
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

        background = [
          {
            monitor = "";
            color = rgba palette.hex.bg "ff";
          }
        ];

        label = {
          monitor = "";
          text = "$FPRINTPROMPT";
          text_align = "center";
          color = rgba palette.hex.text "ff";
          font_size = 24;
          font_family = "JetBrainsMono Nerd Font";
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
          outer_color = rgba palette.hex."border-strong" "ff";
          inner_color = rgba palette.hex.surface "ff";
          font_color = rgba palette.hex.text "ff";
          check_color = rgba palette.hex.accent "ff";
          fail_color = rgba palette.hex."status-err" "ff";

          font_family = "JetBrainsMono Nerd Font";
          font_size = 32;

          placeholder_text = "  Enter Password";
          fail_text = "<i>$PAMFAIL ($ATTEMPTS)</i>";

          rounding = 4;
          shadow_passes = 0;
          fade_on_empty = false;
        };
      };
    };
  };
}
