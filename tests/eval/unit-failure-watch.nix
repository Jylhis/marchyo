# marchyo.notifications.unitFailures: the watcher user unit and its ignore list.
{ lib, ... }:
let
  unit = "marchyo-unit-failure-watch";
in
{
  refs = {
    desktop = {
      eval-unit-failure-watch-enabled =
        c: (c.systemd.user.services ? ${unit}) && c.systemd.user.services.${unit}.enable;
      eval-unit-failure-watch-default-ignore = c: c.marchyo.notifications.unitFailures.ignore == [ ];
    };

    headless.eval-unit-failure-watch-headless-off = c: !(c.systemd.user.services ? ${unit});

    desktop-off.eval-unit-failure-watch-disabled = c: !(c.systemd.user.services ? ${unit});

    desktop-tweaks-4.eval-unit-failure-watch-ignore =
      c:
      lib.any (lib.hasPrefix "MARCHYO_UNIT_FAILURE_IGNORE_FILE=") c.systemd.user.services.${unit}.serviceConfig.Environment
      && c.marchyo.notifications.unitFailures.ignore == [ "foo-*.service" ];
  };

  refConfig = {
    desktop-off.marchyo.notifications.unitFailures.enable = false;
    desktop-tweaks-4.marchyo.notifications.unitFailures.ignore = [ "foo-*.service" ];
  };
}
