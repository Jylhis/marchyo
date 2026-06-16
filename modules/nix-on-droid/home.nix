# Droid Home-Manager config.
#
# Uses HM 24.05 semantics (nix-on-droid's bundled Home Manager): git identity
# via programs.git.userName/userEmail/extraConfig (NOT programs.git.settings,
# which only exists in HM 25.05+). home.username / home.homeDirectory are set
# by nix-on-droid's HM integration, so they are intentionally omitted here.
{ lib, ... }:
{
  home.stateVersion = "24.05";

  programs = {
    git = {
      enable = true;
      userName = lib.mkDefault "Marchyo Developer";
      userEmail = lib.mkDefault "dev@example.org";
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };

    zsh = {
      enable = true;
      enableCompletion = true;
    };

    bash.enable = true;
    bat.enable = true;
    fzf.enable = true;
  };
}
