# Droid Home-Manager config, HM 24.05 semantics (nix-on-droid's bundled HM):
# git identity via programs.git.userName/userEmail/extraConfig, NOT
# programs.git.settings (HM 25.05+ only). home.username / home.homeDirectory
# come from nix-on-droid's HM integration, so they are omitted here. Reuses the
# version-agnostic generic modules; the full modules/home/* tree needs HM
# 25.05+ and is NOT imported.
{ lib, pkgs, ... }:
{
  imports = [
    ../generic/git.nix
    ../generic/shell.nix
  ];

  home.stateVersion = "24.05";

  programs = {
    git = {
      # Override generic/git.nix's gitFull to lightweight git (GUI/Perl extras
      # are dead weight on Android CLI). Plain assignment, not mkDefault: a
      # second mkDefault would conflict with generic/git.nix's at equal priority.
      package = pkgs.git;
      userName = lib.mkDefault "Marchyo Developer";
      userEmail = lib.mkDefault "dev@example.org";
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };

    bash.enable = true;
    bat.enable = true;
    fzf.enable = true;
  };
}
