# Claude Code OpenTelemetry tracking (per-user).
#
# When marchyo.tracking.claudeCode.enable is true, this module exports the
# static OTEL environment and merges an env block into ~/.claude/settings.json.
# The auth header is read from a user-readable file at activation/shell startup
# so the secret does not enter the Nix store.
{
  osConfig ? { },
  lib,
  pkgs,
  ...
}:
let
  trackingCfg = (osConfig.marchyo or { }).tracking or { };
  ccCfg = trackingCfg.claudeCode or { };
  enabled = (trackingCfg.enable or false) && (ccCfg.enable or false);

  authFile = if (ccCfg.authHeaderFile or null) == null then "" else toString ccCfg.authHeaderFile;

  baseEnv = {
    CLAUDE_CODE_ENABLE_TELEMETRY = "1";
    OTEL_METRICS_EXPORTER = "otlp";
    OTEL_LOGS_EXPORTER = "otlp";
    OTEL_EXPORTER_OTLP_PROTOCOL = ccCfg.protocol or "http/protobuf";
    OTEL_EXPORTER_OTLP_ENDPOINT =
      ccCfg.otlpEndpoint or "https://otlp-gateway-prod-eu-west-0.grafana.net/otlp";
    OTEL_METRIC_EXPORT_INTERVAL = toString (ccCfg.metricExportIntervalMs or 10000);
    OTEL_LOGS_EXPORT_INTERVAL = toString (ccCfg.logExportIntervalMs or 5000);
  };

  shellInit = ''
    if [ -r "${authFile}" ]; then
      export OTEL_EXPORTER_OTLP_HEADERS="$(cat "${authFile}")"
    fi
  '';

  fishInit = ''
    if test -r "${authFile}"
        set -gx OTEL_EXPORTER_OTLP_HEADERS (cat "${authFile}")
    end
  '';
in
{
  config = lib.mkIf enabled {
    home.sessionVariables = baseEnv;

    programs.bash.initExtra = shellInit;
    programs.zsh.initExtra = shellInit;
    programs.fish.interactiveShellInit = fishInit;

    home.activation.marchyoClaudeCodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      header=""
      if [ -r "${authFile}" ]; then
        header=$(cat "${authFile}")
      fi
      run mkdir -p "$HOME/.claude"
      newEnv=$(${pkgs.jq}/bin/jq -nc \
        --arg ep  "${baseEnv.OTEL_EXPORTER_OTLP_ENDPOINT}" \
        --arg pr  "${baseEnv.OTEL_EXPORTER_OTLP_PROTOCOL}" \
        --arg mi  "${baseEnv.OTEL_METRIC_EXPORT_INTERVAL}" \
        --arg li  "${baseEnv.OTEL_LOGS_EXPORT_INTERVAL}" \
        --arg hdr "$header" \
        '{
          CLAUDE_CODE_ENABLE_TELEMETRY: "1",
          OTEL_METRICS_EXPORTER: "otlp",
          OTEL_LOGS_EXPORTER: "otlp",
          OTEL_EXPORTER_OTLP_PROTOCOL: $pr,
          OTEL_EXPORTER_OTLP_ENDPOINT: $ep,
          OTEL_METRIC_EXPORT_INTERVAL: $mi,
          OTEL_LOGS_EXPORT_INTERVAL: $li
        } + (if $hdr == "" then {} else { OTEL_EXPORTER_OTLP_HEADERS: $hdr } end)')
      settings="$HOME/.claude/settings.json"
      tmp="$settings.tmp"
      if [ -f "$settings" ]; then
        if ${pkgs.jq}/bin/jq --argjson env "$newEnv" '.env = ((.env // {}) + $env)' "$settings" > "$tmp"; then
          run mv "$tmp" "$settings"
        else
          echo "marchyo: ~/.claude/settings.json is not valid JSON; leaving it untouched" >&2
          rm -f "$tmp"
        fi
      else
        ${pkgs.jq}/bin/jq -n --argjson env "$newEnv" '{env: $env}' > "$tmp"
        run mv "$tmp" "$settings"
      fi
    '';
  };
}
