# nix-on-droid (Android terminal) module for Marchyo.
#
# Deliberately minimal and droid-native. nix-on-droid uses its own module
# system (NOT NixOS) and ships a 2024-era Home Manager (HM 24.05), so this
# imports neither the NixOS modules nor the marchyo Home-Manager modules
# (those require HM 25.05+). Terminal CLI only — no Wayland/desktop.
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

  # Home Manager is wired through nix-on-droid's own integration option.
  home-manager.config = import ./home.nix;
}
