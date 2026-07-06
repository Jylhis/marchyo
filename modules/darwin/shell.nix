# Bash as the default login shell on macOS.
#
# nix-darwin can only change a user's login shell when the user is listed in
# `users.knownUsers`, which requires the exact `uid` of the existing account —
# a wrong uid aborts activation. So the shell switch is opt-in: set
# `marchyo.users.<name>.uid` (first macOS user is 501) and marchyo manages the
# shell declaratively. Without a uid, bash 5.x is still registered in
# /etc/shells so a one-time `chsh -s /run/current-system/sw/bin/bash` works.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  mUsers = lib.filterAttrs (_name: user: user.enable) config.marchyo.users;
  usersWithUid = lib.filterAttrs (_name: user: user.uid != null) mUsers;
in
{
  # bash 5.x from nixpkgs (macOS ships an ancient 3.2), registered in /etc/shells.
  environment.shells = [ pkgs.bashInteractive ];

  # /etc/bashrc with nix-darwin session init so bash login shells get the Nix
  # environment, plus programmable completion.
  programs.bash = {
    enable = true;
    completion.enable = true;
  };

  users.knownUsers = lib.attrNames usersWithUid;
  users.users = lib.mapAttrs (_name: user: {
    inherit (user) uid;
    shell = lib.mkDefault pkgs.bashInteractive;
  }) usersWithUid;
}
