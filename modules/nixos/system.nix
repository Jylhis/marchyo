{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit ((import ../../lib { inherit lib; })) mapListToAttrs;
  mUsers = lib.filterAttrs (_name: user: user.enable) config.marchyo.users;
  forMarchyoUsers = attr: mapListToAttrs (builtins.attrNames mUsers) (_name: attr);
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
