# kitty terminal config. Opt-in: marchyo's default terminal is ghostty, so
# this only applies when the consumer has enabled kitty (programs.kitty.enable).
# Cross-platform (the macos_option_as_alt tweak is darwin-gated).
{
  lib,
  pkgs,
  config,
  ...
}:
{
  programs.kitty = lib.mkIf config.programs.kitty.enable {
    enableGitIntegration = config.programs.git.enable;
    shellIntegration.mode = "rc profile";

    settings = lib.mkMerge [
      {
        bold_italic_font = "auto";
        window_padding_width = 14;
        window_padding_height = 14;
        cursor_shape = "block";
        cursor_blink_interval = 0;
        confirm_os_window_close = 0;
        single_instance = true;
        allow_remote_control = "socket-only";

        # Tab configuration
        tab_bar_style = "powerline";
        tab_bar_edge = "bottom";
        tab_title_template = "{title}{' :{}:'.format(num_windows) if num_windows > 1 else ''}";

        # Window configuration
        inactive_text_alpha = lib.mkDefault "0.7";
        active_border_color = lib.mkDefault "none";
        remember_window_size = false;

        # Layout
        enabled_layouts = "splits,horizontal,vertical,tall";
        enable_audio_bell = "no";
      }
      (lib.mkIf pkgs.stdenv.isDarwin {
        macos_option_as_alt = true;
      })
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
