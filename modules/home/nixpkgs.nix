{ lib, pkgs, ... }:
{
  # pkgs is the system package set (home-manager.useGlobalPkgs), so a host that
  # turns nixpkgs.config.allowUnfree off gets neither setting.
  config = lib.mkIf (pkgs.config.allowUnfree or false) {
    home.sessionVariables.NIXPKGS_ALLOW_UNFREE = "1";
    xdg.configFile."nixpkgs/config.nix".text = "{ allowUnfree = true; }";
  };
}
