{ lib, ... }:
let
  inherit (lib) mkOption types;

  lidAction = types.enum [
    "ignore"
    "poweroff"
    "reboot"
    "halt"
    "kexec"
    "suspend"
    "hibernate"
    "hybrid-sleep"
    "suspend-then-hibernate"
    "lock"
  ];

  lidOption =
    default: description:
    mkOption {
      type = lidAction;
      inherit default description;
    };
in
{
  options.marchyo.power = {
    hibernation = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable hibernation. Sets `boot.resumeDevice` from `resumeDevice`,
          makes suspend actions (lid, suspend key) suspend-then-hibernate
          after `suspendThenHibernateDelay`, and shows Hibernate in the power
          menus. Needs a swap device at least as large as RAM.
        '';
      };

      resumeDevice = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/dev/disk/by-uuid/0f0c0a5e-0000-4000-8000-000000000000";
        description = ''
          Device that holds the hibernation image. Null leaves
          `boot.resumeDevice` to the host. When null, `swapDevices` must be
          non-empty (or the host sets `boot.resumeDevice` itself).
        '';
      };

      suspendThenHibernateDelay = mkOption {
        type = types.str;
        default = "2h";
        example = "30min";
        description = "Time a suspended machine sleeps before it hibernates (systemd `HibernateDelaySec`).";
      };
    };

    lid = {
      onBattery = lidOption "suspend" "Action when the lid closes on battery power.";
      onAC = lidOption "suspend" "Action when the lid closes on external power.";
      docked = lidOption "ignore" ''
        Action when the lid closes while another display is connected or the
        machine is docked.
      '';
    };
  };
}
