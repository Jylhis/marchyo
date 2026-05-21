{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.performance = {
    disableMitigations = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Disable CPU vulnerability mitigations (Spectre, Meltdown, etc.) for maximum performance.
        WARNING: This reduces security. Only enable on trusted single-user workstations
        where maximum performance is required (e.g., gaming, benchmarking).
        Do NOT enable if running untrusted code or containers.
      '';
    };
  };
}
