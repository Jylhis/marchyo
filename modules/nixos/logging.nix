# Global (headless-safe): journald limits.
{ config, lib, ... }:
let
  cfg = config.marchyo.logging.journal;
in
{
  services.journald.settings.Journal = lib.mkMerge [
    (lib.mkIf (cfg.maxUse != null) { SystemMaxUse = cfg.maxUse; })
    (lib.mkIf (cfg.retention != null) { MaxRetentionSec = cfg.retention; })
  ];
}
