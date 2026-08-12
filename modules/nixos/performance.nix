{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.performance;

  # marchyo.performance.kernel enum -> kernel package set ("default" leaves
  # boot.kernelPackages unmanaged; see the option description).
  kernelPackages = {
    latest = pkgs.linuxPackages_latest;
    zen = pkgs.linuxPackages_zen;
    xanmod = pkgs.linuxPackages_xanmod_latest;
    lts = pkgs.linuxPackages;
  };
in
{
  boot.kernelParams = lib.mkIf cfg.disableMitigations [
    "mitigations=off"
  ];

  boot.kernelPackages = lib.mkIf (cfg.kernel != "default") (
    lib.mkDefault kernelPackages.${cfg.kernel}
  );

  warnings = lib.optional (config.marchyo.development.enable && cfg.disableMitigations) ''
    marchyo: CPU mitigations are disabled (marchyo.performance.disableMitigations
    = true) while the container stack is enabled (marchyo.development.enable).
    This is fine for trusted local workloads, but do not run untrusted containers
    in this configuration. Set marchyo.performance.disableMitigations = false to
    re-enable mitigations.
  '';
}
