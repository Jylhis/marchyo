{ config, lib, ... }:
{
  boot.kernelParams = lib.mkIf config.marchyo.performance.disableMitigations [
    "mitigations=off"
  ];
}
