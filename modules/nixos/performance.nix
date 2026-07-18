{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.performance;

  # marchyo.performance.kernel enum -> kernel package set. Evaluated lazily,
  # so only the selected variant is ever forced.
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

  # "default" leaves boot.kernelPackages unmanaged; any other variant is set
  # with mkDefault so hosts can still override boot.kernelPackages directly.
  boot.kernelPackages = lib.mkIf (cfg.kernel != "default") (
    lib.mkDefault kernelPackages.${cfg.kernel}
  );

  # disableMitigations defaults to true, while marchyo.development.enable turns
  # on Docker and adds every marchyo user to the (root-equivalent) docker group.
  # Running containers with CPU mitigations disabled weakens isolation against
  # untrusted workloads — surface the tension rather than silently combining them.
  warnings = lib.optional (config.marchyo.development.enable && cfg.disableMitigations) ''
    marchyo: CPU mitigations are disabled (marchyo.performance.disableMitigations
    = true) while the container stack is enabled (marchyo.development.enable).
    This is fine for trusted local workloads, but do not run untrusted containers
    in this configuration. Set marchyo.performance.disableMitigations = false to
    re-enable mitigations.
  '';
}
