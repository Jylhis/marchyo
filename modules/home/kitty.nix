{ config, pkgs, ... }:
{
  programs.kitty = {
    enable = true;
    enableGitIntegration = config.programs.git.enable;
    shellIntegration.mode = "rc profile";
    font = {
      # name = "JetBrainsMono Nerd Font";
      name = "CaskaydiaMono Nerd Font";
      package = pkgs.nerd-fonts.caskaydia-mono;
      size = 12;
    };
    settings = {
      bold_italic_font = "auto";
      background_opacity = "0.95";
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
      inactive_text_alpha = "0.7";
      active_border_color = "none";
      remember_window_size = false;

      wayland_enable_ime = false;

      # Layout
      enabled_layouts = "splits,horizontal,vertical,tall";
      enable_audio_bell = "no";
    };
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
    };
  };
}
