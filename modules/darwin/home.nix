# Home Manager wiring for marchyo users on nix-darwin.
#
# The darwin counterpart of modules/nixos/system.nix's home-manager.users
# block, but with a hand-curated darwin-safe subset of modules/home/* (the
# full ../home tree is Wayland/Hyprland-heavy and must never be imported
# wholesale here — same curated-subset policy as modules/darwin/default.nix).
{ config, lib, ... }:
let
  mUsers = lib.filterAttrs (_name: user: user.enable) config.marchyo.users;
in
{
  config = lib.mkIf (mUsers != { }) {
    # Backup existing files with this extension when home-manager overwrites them
    home-manager.backupFileExtension = "backup";

    # HM on darwin needs the user's home directory set; default the macOS
    # convention, overridable downstream.
    users.users = lib.mapAttrs (name: _user: {
      home = lib.mkDefault "/Users/${name}";
    }) mUsers;

    home-manager.users = lib.mapAttrs (_name: _user: {
      imports = [
        # Curated darwin-safe subset of ../home
        ../home/shell.nix
        ../home/packages.nix
        ../home/fzf.nix
        ../home/bat.nix
        ../home/direnv.nix
        ../home/ssh.nix
        ../home/ghostty.nix
        ../home/git.nix
        ../home/btop.nix
        ../home/starship.nix
        ../generic/shell.nix
        ../generic/packages.nix
        ../generic/git.nix
      ];
      # darwin's system.stateVersion is an int, so the HM stateVersion cannot
      # be derived from it the way modules/nixos/system.nix does.
      home.stateVersion = lib.mkDefault "26.05";
    }) mUsers;
  };
}
