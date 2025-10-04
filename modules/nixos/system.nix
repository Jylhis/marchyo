{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit ((import ../../lib { inherit lib; })) mapListToAttrs;
  mUsers = lib.filterAttrs (_name: user: user.enable) config.marchyo.users;
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

  # Create users defined in marchyo.users
  users.users = mapListToAttrs (builtins.attrNames mUsers) (
    name:
    let
      user = mUsers.${name};
    in
    {
      isNormalUser = true;
      description = user.fullname;
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
    }
  );
}
