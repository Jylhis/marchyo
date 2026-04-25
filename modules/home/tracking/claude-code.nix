# Claude Code OpenTelemetry tracking (per-user).
#
# When `marchyo.tracking.claudeCode.enable` is true at the system level,
# this module:
#   * sets the static OTEL_* / CLAUDE_CODE_ENABLE_TELEMETRY env vars via
#     home.sessionVariables (picked up by login shells / display managers);
#   * exports OTEL_EXPORTER_OTLP_HEADERS in interactive bash/zsh/fish
#     sessions by reading `authHeaderFile` at shell init (so the secret
#     never enters the Nix store);
#   * regenerates ~/.claude/settings.json at home-manager activation,
#     embedding the same env block (including the header read from the
#     auth file) so launcher- and IDE-launched Claude Code sessions also
#     get the telemetry config.
{
  osConfig ? { },
  lib,
  pkgs,
  ...
}:
let
  trackingCfg = osConfig.marchyo.tracking or { };
  ccCfg = trackingCfg.claudeCode or { };
  enabled = (trackingCfg.enable or false) && (ccCfg.enable or false);

  authFile = toString (ccCfg.authHeaderFile or "");

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

    # Merge the OTEL `env` block into ~/.claude/settings.json without
    # touching other user-managed keys (model, theme, hooks, permissions, …).
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
