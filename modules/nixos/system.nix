# Global (headless-safe): users, home-manager wiring, base services.
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
    earlyoom.enable = lib.mkDefault true;
  };

  # One OOM killer: oomd watches no slices by default, so it is redundant here.
  systemd.oomd.enable = lib.mkDefault (!config.services.earlyoom.enable);

  programs = {
    nix-ld.enable = lib.mkDefault true;
  };

  environment.systemPackages = with pkgs; [
    sysz
    lazyjournal
    # xterm-ghostty terminfo so inbound SSH sessions from Ghostty clients get
    # working TUI applications (colors, keys) instead of a missing-terminfo TERM.
    ghostty.terminfo
  ];

  # Bash is the marchyo default login shell on every platform. NixOS already
  # defaults to bash; set it explicitly (bashInteractive = bash 5.x) so the
  # choice is declared rather than inherited, and overridable per consumer.
  users.defaultUserShell = lib.mkDefault pkgs.bashInteractive;

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

      # Value-level mkIf (not optionalAttrs): the submodule's attribute shape
      # must not depend on `name`, which resolves through _module.args and
      # would recurse into the config fixpoint.
      uid = lib.mkIf (mUsers.${name}.uid != null) mUsers.${name}.uid;
    }
  );
}
