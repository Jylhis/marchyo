{ config, lib, ... }:
{
  boot.kernelParams = lib.mkIf config.marchyo.performance.disableMitigations [
    "mitigations=off"
  ];

  # disableMitigations defaults to true, while marchyo.development.enable turns
  # on Docker and adds every marchyo user to the (root-equivalent) docker group.
  # Running containers with CPU mitigations disabled weakens isolation against
  # untrusted workloads — surface the tension rather than silently combining them.
  warnings =
    lib.optional (config.marchyo.development.enable && config.marchyo.performance.disableMitigations)
      ''
        marchyo: CPU mitigations are disabled (marchyo.performance.disableMitigations
        = true) while the container stack is enabled (marchyo.development.enable).
        This is fine for trusted local workloads, but do not run untrusted containers
        in this configuration. Set marchyo.performance.disableMitigations = false to
        re-enable mitigations.
      '';
}
