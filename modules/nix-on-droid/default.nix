# nix-on-droid (Android terminal) module for Marchyo. nix-on-droid uses its
# own module system (NOT NixOS) and ships HM 24.05, so this imports neither the
# NixOS modules nor the marchyo Home-Manager modules (those need HM 25.05+).
# Terminal CLI only, no Wayland/desktop.
{ pkgs, ... }:
{
  environment.packages = with pkgs; [
    git
    openssh
    ripgrep
    fd
    eza
    bat
    jq
    fzf
  ];

  home-manager.config = import ./home.nix;
}
