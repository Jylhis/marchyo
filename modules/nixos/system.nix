{
  config,
  lib,
  pkgs,
  ...
}:
let
  mUsers = lib.filterAttrs (_name: user: user.enable) config.marchyo.users;
  forMarchyoUsers = attr: lib.mapAttrs (_name: _user: attr) mUsers;
in
{
  services = {
    earlyoom.enable = true;
  };

  programs = {
    nix-ld.enable = true;
  };

  environment.systemPackages = with pkgs; [
    sysz # systemctl tui
    lazyjournal # journald and logs
    # xterm-ghostty terminfo so inbound SSH sessions from Ghostty clients get
    # working TUI applications (colors, keys) instead of a missing-terminfo TERM.
    ghostty.terminfo
  ];

  # Bash is the marchyo default login shell on every platform. NixOS already
  # defaults to bash; set it explicitly (bashInteractive = bash 5.x) so the
  # choice is declared rather than inherited, and overridable per consumer.
  users.defaultUserShell = lib.mkDefault pkgs.bashInteractive;

  # Backup existing files with this extension when home-manager overwrites them
  home-manager.backupFileExtension = "backup";

  home-manager.users = forMarchyoUsers (
    { osConfig, ... }:
    {
      imports = [
        ../home
      ];
      home.stateVersion = lib.mkDefault osConfig.system.stateVersion;
    }
  );

  users.users = forMarchyoUsers (
    { name, ... }:
    {

      isNormalUser = true;
      description = mUsers.${name}.fullname;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];

    }
    // lib.optionalAttrs (mUsers.${name}.uid != null) {
      inherit (mUsers.${name}) uid;
    }
  );
}
