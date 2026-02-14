{
  lib,
  config,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf mkMerge mkDefault;
  hasOsConfig = osConfig != { } && osConfig ? marchyo;
  cfg = if hasOsConfig then osConfig.marchyo.theme else null;
in
{
  programs.kitty = {
    enable = true;
    enableGitIntegration = config.programs.git.enable;
    shellIntegration.mode = "rc profile";

    settings = mkMerge [
      {
        bold_italic_font = "auto";
        # background_opacity = "0.95";
        window_padding_width = 14;
        window_padding_height = 14;
        hide_window_decorations = true;
        show_window_resize_notification = false;
        cursor_shape = "block";
        cursor_blink_interval = 0;
        confirm_os_window_close = 0;
        single_instance = true;
        allow_remote_control = true;

        # Tab configuration
        tab_bar_style = "powerline";
        tab_bar_edge = "bottom";
        tab_title_template = "{title}{' :{}:'.format(num_windows) if num_windows > 1 else ''}";

        # Window configuration
        inactive_text_alpha = mkDefault "0.7";
        active_border_color = mkDefault "none";
        remember_window_size = false;

        # Enable Wayland input method support for fcitx5
        wayland_enable_ime = true;

        # Layout
        enabled_layouts = "splits,horizontal,vertical,tall";
        enable_audio_bell = "no";
      }
      (mkIf (cfg != null && cfg.enable && config ? colorScheme) (
        with config.colorScheme.palette;
        {
          # UI Colors
          foreground = "#${base05}";
          background = "#${base00}";
          selection_background = "#${base05}";
          selection_foreground = "#${base00}";
          cursor = "#${base05}";
          cursor_text_color = "#${base00}";

          # URL underline color
          url_color = "#${base0D}";

          # Terminal Colors (16 ANSI colors)
          color0 = "#${base00}"; # black
          color1 = "#${base08}"; # red
          color2 = "#${base0B}"; # green
          color3 = "#${base0A}"; # yellow
          color4 = "#${base0D}"; # blue
          color5 = "#${base0E}"; # magenta
          color6 = "#${base0C}"; # cyan
          color7 = "#${base05}"; # white
          color8 = "#${base03}"; # bright black
          color9 = "#${base08}"; # bright red
          color10 = "#${base0B}"; # bright green
          color11 = "#${base0A}"; # bright yellow
          color12 = "#${base0D}"; # bright blue
          color13 = "#${base0E}"; # bright magenta
          color14 = "#${base0C}"; # bright cyan
          color15 = "#${base07}"; # bright white

          # Tab bar colors
          active_tab_foreground = "#${base00}";
          active_tab_background = "#${base0D}";
          inactive_tab_foreground = "#${base04}";
          inactive_tab_background = "#${base01}";

          # Border colors
          active_border_color = "#${base0D}";
          inactive_border_color = "#${base03}";
        }
      ))
    ];
    keybindings = {
      "alt+1" = "goto_tab 1";
      "alt+2" = "goto_tab 2";
      "alt+3" = "goto_tab 3";
      "alt+4" = "goto_tab 4";
      "alt+5" = "goto_tab 5";
      "alt+6" = "goto_tab 6";
      "alt+7" = "goto_tab 7";
      "alt+8" = "goto_tab 8";
      "alt+9" = "goto_tab 9";
      "f11" = "toggle_fullscreen";
    };
  };
}
