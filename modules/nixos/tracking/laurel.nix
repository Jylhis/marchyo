# Laurel: audisp plugin that converts auditd records to JSON Lines for the
# Vector pipeline. Wired in only when both auditd and aggregation are on,
# since laurel exists to feed the aggregation sink.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  enable = cfg.enable && cfg.system.auditd && cfg.aggregation.enable;
in
{
  config = lib.mkIf enable {
    users.users._laurel = {
      isSystemUser = true;
      group = "_laurel";
      home = "/var/log/laurel";
      createHome = true;
      description = "Laurel audisp plugin";
    };
    users.groups._laurel = { };

    # Vector (started by services.vector in aggregation.nix) needs read
    # access to the laurel JSON output. The laurel config sets mode=0640
    # with group=_laurel, so vector must be in _laurel. Vector runs under
    # systemd's DynamicUser, so we extend its SupplementaryGroups rather
    # than touching users.users.vector. journaldAccess is enabled on the
    # aggregation side, so re-include systemd-journal explicitly here.
    systemd.services.vector.serviceConfig.SupplementaryGroups = lib.mkForce "systemd-journal _laurel";

    systemd.tmpfiles.rules = [
      "d /var/log/laurel 0750 _laurel _laurel -"
    ];

    security.auditd.plugins.laurel = {
      active = true;
      direction = "out";
      path = "${pkgs.laurel}/bin/laurel";
      args = [
        "--config"
        "/etc/laurel/config.toml"
      ];
      format = "string";
    };

    environment.etc."laurel/config.toml".text = ''
      [auditlog]
      file = "/var/log/laurel/audit.log"
      read-users = []
      group = "_laurel"
      mode = "0640"
      size = 134217728
      generations = 16

      [privileges]
      user = "_laurel"
      group = "_laurel"

      [enrich]
      execve-env = ["LD_PRELOAD", "LD_LIBRARY_PATH"]
      container = true
      systemd = true
      pid = true
      script = true

      [transform]
      execve-argv = "array"

      [filter]
      keep-first-per-process = true
    '';
  };
}
