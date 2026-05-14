{ lib, ... }:
{
  config = {
    programs.fzf = {
      enable = true;
      enableBashIntegration = lib.mkDefault true;
      enableZshIntegration = lib.mkDefault true;

      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
      ];

      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
      fileWidgetOptions = [
        "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
      ];

      changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
      changeDirWidgetOptions = [
        "--preview 'eza --tree --level=2 --icons --color=always {}'"
      ];

      historyWidgetOptions = [
        "--sort"
        "--exact"
      ];
    };
  };
}
