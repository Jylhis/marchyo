{
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
        color = "rgb(211, 198, 170)";
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

        # inner_color = surfaceRgb;
        # outer_color = foregroundRgb; # #d3c6aa
        outline_thickness = 4;

        font_family = "CaskaydiaMono Nerd Font";
        font_size = 32;
        # font_color = foregroundRgb;

        # placeholder_color = foregroundMutedRgb;
        placeholder_text = "  Enter Password 󰈷";
        check_color = "rgba(131, 192, 146, 1.0)";
        fail_text = "<i>$PAMFAIL ($ATTEMPTS)</i>";

        rounding = 0;
        shadow_passes = 0;
        fade_on_empty = false;
      };
    };
  };
}
