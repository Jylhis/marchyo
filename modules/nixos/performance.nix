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
  # No lib.mkDefault here, unlike boot.kernelPackages below: kernelParams is a
  # list option, so definitions concatenate rather than compete on priority and
  # a default would not make the entry removable. Opting out is done through
  # marchyo.performance.disableMitigations, which drops the entry entirely.
  boot.kernelParams = lib.mkIf cfg.disableMitigations [
    "mitigations=off"
  ];

  boot.kernelPackages = lib.mkIf (cfg.kernel != "default") (
    lib.mkDefault kernelPackages.${cfg.kernel}
  );

  # Warn on any container runtime, not just marchyo.development.enable — a host
  # that turns on podman or docker directly is in the same position.
  warnings =
    let
      containerRuntime =
        config.marchyo.development.enable
        || config.virtualisation.podman.enable
        || config.virtualisation.docker.enable;
    in
    lib.optional (containerRuntime && cfg.disableMitigations) ''
      marchyo: CPU mitigations are disabled (marchyo.performance.disableMitigations
      = true, which is the default) while a container runtime is enabled. This is
      fine for trusted local workloads, but do not run untrusted containers in
      this configuration. Set marchyo.performance.disableMitigations = false to
      re-enable mitigations.
    '';
}
