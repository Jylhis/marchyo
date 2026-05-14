{ lib, ... }:
{
  config = {
    programs.fzf = {
      enable = true;
      enableBashIntegration = lib.mkDefault true;
      enableZshIntegration = lib.mkDefault true;

      defaultCommand = lib.mkDefault "fd --type f --hidden --follow --exclude .git";
      defaultOptions = lib.mkDefault [
        "--height=40%"
        "--layout=reverse"
        "--border"
      ];

      fileWidgetOptions = lib.mkDefault [
        "--preview 'bat --style=numbers --color=always --line-range :500 {}'"
      ];

      changeDirWidgetCommand = lib.mkDefault "fd --type d --hidden --follow --exclude .git";
      changeDirWidgetOptions = lib.mkDefault [
        "--preview 'eza --tree --level=2 --icons --color=always {}'"
      ];

      historyWidgetOptions = lib.mkDefault [
        "--sort"
        "--exact"
      ];
    };
  };
}
