# Claude Code OpenTelemetry tracking (NixOS coordinator).
#
# The actual configuration (settings.json + shell init) is written by
# `modules/home/tracking/claude-code.nix` per user. This module exists to
# keep the tracking namespace consistent and to fail the build with a
# helpful message when the option set is incomplete.
{ config, lib, ... }:
let
  cfg = config.marchyo.tracking;
  ccCfg = cfg.claudeCode;
in
{
  config = lib.mkIf (cfg.enable && ccCfg.enable) {
    assertions = [
      {
        assertion = ccCfg.authHeaderFile != null && ccCfg.authHeaderFile != "";
        message = ''
          marchyo.tracking.claudeCode.enable = true requires
          marchyo.tracking.claudeCode.authHeaderFile to point at a file
          containing the OTEL_EXPORTER_OTLP_HEADERS value, e.g.

              "Authorization=Basic <base64(instanceId:token)>"
        '';
      }
    ];
  };
}
