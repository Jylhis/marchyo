{ lib, pkgs, ... }:
{
  programs = {

    git = {
      enable = true;
      package = lib.mkDefault pkgs.gitFull;
      lfs.enable = true;
    };
    lazygit = {
      enable = true;
    };
  };

}
