{
  config,
  lib,
  pkgs,
  ...
}:
let
  mUsers = lib.filterAttrs (_name: user: user.enable) config.marchyo.users;
  forMarchyoUsers = attr: lib.genAttrs (builtins.attrNames mUsers) (_name: attr);
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
  ];

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
  );
}
