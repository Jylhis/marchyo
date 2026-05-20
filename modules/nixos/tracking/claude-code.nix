# Claude Code OpenTelemetry tracking (NixOS coordinator).
#
# The per-user settings are written by modules/home/tracking/claude-code.nix.
# This module keeps validation at the system option level so incomplete
# telemetry configuration fails during evaluation with a focused message.
{ config, lib, ... }:
let
  cfg = config.marchyo.tracking;
  ccCfg = cfg.claudeCode;
in
{
  config = lib.mkIf (cfg.enable && ccCfg.enable) {
    assertions = [
      {
        assertion = ccCfg.authHeaderFile != null;
        message = ''
          marchyo.tracking.claudeCode.enable = true requires
          marchyo.tracking.claudeCode.authHeaderFile to point at a file
          containing the OTEL_EXPORTER_OTLP_HEADERS value, for example:

              Authorization=Basic <base64(instanceId:token)>
        '';
      }
    ];
  };
}
