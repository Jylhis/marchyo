# Global (headless-safe): CPU mitigations.
{
  config,
  lib,
  ...
}:
let
  cfg = config.marchyo.performance;
in
{
  boot.kernelParams = lib.mkIf cfg.disableMitigations [
    "mitigations=off"
  ];
}
