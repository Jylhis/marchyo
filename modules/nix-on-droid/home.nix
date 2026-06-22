# Droid Home-Manager config.
#
# Uses HM 24.05 semantics (nix-on-droid's bundled Home Manager): git identity
# via programs.git.userName/userEmail/extraConfig (NOT programs.git.settings,
# which only exists in HM 25.05+). home.username / home.homeDirectory are set
# by nix-on-droid's HM integration, so they are intentionally omitted here.
#
# Reuses the HM-version-agnostic marchyo generic modules — generic/git.nix
# (enable + lfs + git package, guarded by an option check) and generic/shell.nix
# (shared bash/zsh aliases). The full modules/home/* tree needs HM 25.05+ and is
# still NOT imported here.
{ lib, pkgs, ... }:
{
  imports = [
    ../generic/git.nix
    ../generic/shell.nix
  ];

  home.stateVersion = "24.05";

  programs = {
    git = {
      # generic/git.nix defaults to gitFull; on an Android CLI its GUI/Perl
      # extras are dead weight, so override to the lightweight git. Plain
      # assignment (not mkDefault) — a second mkDefault would conflict with
      # generic/git.nix's own mkDefault at equal priority.
      package = pkgs.git;
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
