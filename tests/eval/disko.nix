# The disko/ layouts, exported as lib.diskoLayout and imported next to
# nixosModules.disko. One light check per layout: evaluate a NixOS system on a
# dummy disk and force the disko devices and the fileSystems they produce.
{
  lib,
  pkgs,
  diskoModule,
  diskoLayout,
  diskoLayouts,
  ...
}:
let
  # raid1 takes two disks; every other layout takes one.
  argsFor =
    name:
    if name == "luks-btrfs-raid1" then
      {
        deviceA = "/dev/disk/by-id/test-a";
        deviceB = "/dev/disk/by-id/test-b";
      }
    else
      { device = "/dev/disk/by-id/test"; };

  check =
    name:
    let
      inherit
        (lib.nixosSystem {
          inherit (pkgs.stdenv.hostPlatform) system;
          modules = [
            diskoModule
            (diskoLayout name (argsFor name))
            {
              system.stateVersion = "25.11";
              boot.loader.systemd-boot.enable = true;
            }
          ];
        })
        config
        ;
      disks = builtins.attrNames config.disko.devices.disk;
      mounts = builtins.attrNames config.fileSystems;
      result =
        disks != [ ]
        && builtins.elem "/" mounts
        && builtins.elem "/boot" mounts
        && builtins.all (m: config.fileSystems.${m}.device != "") mounts;
    in
    pkgs.writeText "eval-disko-${name}" (
      if builtins.deepSeq [ disks mounts ] result then
        "pass"
      else
        throw "FAIL: disko-${name}: missing devices or mounts (disks: ${toString disks}; mounts: ${toString mounts})"
    );
in
{
  # Plain NixOS evaluations (no marchyo modules), one per layout: they share
  # nothing with the reference systems, so they stay standalone checks.
  checks =
    lib.listToAttrs (map (name: lib.nameValuePair "eval-disko-${name}" (check name)) diskoLayouts)
    // {
      eval-disko-unknown-layout = pkgs.writeText "eval-disko-unknown-layout" (
        if (builtins.tryEval (diskoLayout "no-such-layout" { })).success then
          throw "FAIL: diskoLayout accepted an unknown layout"
        else
          "pass"
      );
    };
}
