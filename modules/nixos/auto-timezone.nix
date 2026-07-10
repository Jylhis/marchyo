{ lib, config, ... }:
let
  cfg = config.marchyo;
in
{
  config = lib.mkIf cfg.autoTimezone.enable {
    # geoclue-based daemon that keeps the timezone current via systemd-timedated.
    # locale.nix sets time.timeZone with lib.mkDefault, which automatic-timezoned
    # tolerates (it requires the static timezone to be at or below default
    # priority), so no mkForce is needed here.
    services.automatic-timezoned.enable = true;
    services.geoclue2.enable = lib.mkDefault true;

    # Setting a non-default marchyo.timezone alongside autoTimezone is
    # contradictory — the daemon wins. Surface that rather than silently ignoring.
    warnings = lib.optional (cfg.timezone != "Europe/Zurich") ''
      marchyo.autoTimezone.enable is on, so marchyo.timezone ("${cfg.timezone}")
      is ignored — the timezone is set automatically from your location.
    '';
  };
}
