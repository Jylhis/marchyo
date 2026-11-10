# Global (headless-safe): CPU mitigations.
{
  config,
  lib,
  options,
  ...
}:
let
  cfg = config.marchyo.performance;
in
{
  # No lib.mkDefault here: kernelParams is a
  # list option, so definitions concatenate rather than compete on priority and
  # a default would not make the entry removable. Opting out is done through
  # marchyo.performance.disableMitigations, which drops the entry entirely.
  boot.kernelParams = lib.mkIf cfg.disableMitigations [
    "mitigations=off"
  ];

  # Warn on any container runtime, not just marchyo.development.enable — a host
  # that turns on podman or docker directly is in the same position. Only when
  # disableMitigations is left at its default: an explicit choice (either way)
  # is an acknowledged trade-off and silences the advisory.
  warnings =
    let
      containerRuntime =
        config.marchyo.development.enable
        || config.virtualisation.podman.enable
        || config.virtualisation.docker.enable;
      explicitChoice = options.marchyo.performance.disableMitigations.highestPrio < 1500;
    in
    lib.optional (containerRuntime && cfg.disableMitigations && !explicitChoice) ''
      marchyo: CPU mitigations are disabled (marchyo.performance.disableMitigations
      = true, which is the default) while a container runtime is enabled. This is
      fine for trusted local workloads, but do not run untrusted containers in
      this configuration. Set marchyo.performance.disableMitigations = false to
      re-enable mitigations, or set it explicitly to true to keep them off and
      silence this warning.
    '';
}
