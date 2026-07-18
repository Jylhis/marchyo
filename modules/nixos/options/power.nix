{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.power.hibernation = {
    enable = lib.mkEnableOption "hibernation (suspend-to-disk) support";

    resumeDevice = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/dev/disk/by-label/swap";
      description = ''
        Device path for boot.resumeDevice — the swap device the kernel resumes
        from. Required for hibernate-to-disk; the device needs swap >= RAM to
        hold the hibernation image.
      '';
    };

    suspendThenHibernate = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Use suspend-then-hibernate for lid close and idle: the machine
        suspends first (fast wake) and hibernates after a delay (zero power
        draw on longer breaks). Set false to keep plain suspend for lid/idle
        and hibernate only on explicit request.
      '';
    };
  };
}
