{ config, ... }:
{
  programs = {
    bash.enable = true;
    jq.enable = true;
    eza = {
      enable = true;
      git = config.programs.git.enable;
      icons = "auto";
    };

    nh.enable = true;
    ripgrep.enable = true;
    fd = {
      enable = true;

    };
    fzf.enable = true;
    aria2.enable = true;
    tealdeer = {
      enable = true;
    };
  };
}
