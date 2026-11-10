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
          Enable hibernation. Makes suspend actions (lid, suspend key)
          suspend-then-hibernate after `suspendThenHibernateDelay`, and shows
          Hibernate in the power menus. Needs a swap device at least as large
          as RAM; set `boot.resumeDevice` when it is not the only swap device.
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
