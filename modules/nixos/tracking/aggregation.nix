# Aggregation: Vector log shipper + DuckDB for ad-hoc analytics.
#
# Tails the JSONL event streams in each configured marchyo user's data
# directory and either forwards them to a Loki endpoint or drops them into
# a local blackhole sink when no endpoint is configured.
#
# When `aggregation.grafanaCloud.enable = true`, Vector forwards parsed
# events to Grafana Cloud Loki (basic auth, token from EnvironmentFile)
# and optionally scrapes the local node_exporter to push host metrics to
# Grafana Cloud Mimir via Prometheus remote_write.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  aggCfg = cfg.aggregation;
  gcCfg = aggCfg.grafanaCloud;
  mUsers = builtins.attrNames config.marchyo.users;

  jsonlPaths = map (u: "${config.users.users.${u}.home}/${cfg.dataDir}/*.jsonl") mUsers;

  # Laurel ships /var/log/laurel/audit.log only when auditd is also on; the
  # laurel module is gated on the same condition so this source is only
  # reachable when the file actually exists.
  laurelEnabled = cfg.system.auditd;
  parseInputs = [ "activity_logs" ] ++ lib.optional laurelEnabled "audit_logs";

  activityLogsSource = {
    type = "file";
    include = jsonlPaths;
    read_from = "beginning";
  };

  auditLogsSource = {
    type = "file";
    include = [ "/var/log/laurel/audit.log" ];
    read_from = "beginning";
  };

  promScrapeSource = {
    type = "prometheus_scrape";
    endpoints = [ "http://127.0.0.1:9100/metrics" ];
    scrape_interval_secs = 30;
  };

  metricSources = lib.optionalAttrs (gcCfg.enable && gcCfg.prometheus.enable) {
    prom_scrape = promScrapeSource;
  };

  vectorSources = {
    activity_logs = activityLogsSource;
  }
  // lib.optionalAttrs laurelEnabled { audit_logs = auditLogsSource; }
  // metricSources;

  selfHostedLokiSink = {
    type = "loki";
    inputs = [ "parse" ];
    endpoint = aggCfg.lokiEndpoint;
    encoding.codec = "json";
    labels = {
      source = "marchyo-tracking";
      type = "{{ type }}";
      host = "{{ host }}";
    };
  };

  grafanaCloudLokiSink = {
    type = "loki";
    inputs = [ "parse" ];
    inherit (gcCfg.loki) endpoint;
    encoding.codec = "json";
    auth = {
      strategy = "basic";
      user = gcCfg.loki.userId;
      password = "\${GRAFANA_CLOUD_LOKI_TOKEN}";
    };
    labels = {
      source = "marchyo-tracking";
      type = "{{ type }}";
      host = "{{ host }}";
    };
  };

  blackholeSink = {
    type = "blackhole";
    inputs = [ "parse" ];
    print_interval_secs = 3600;
  };

  promRemoteWriteSink = {
    type = "prometheus_remote_write";
    inputs = [ "prom_scrape" ];
    inherit (gcCfg.prometheus) endpoint;
    auth = {
      strategy = "basic";
      user = gcCfg.prometheus.userId;
      password = "\${GRAFANA_CLOUD_PROM_TOKEN}";
    };
  };

  logSinks =
    if gcCfg.enable then
      { grafana_cloud_loki = grafanaCloudLokiSink; }
    else if aggCfg.lokiEndpoint != null then
      { loki = selfHostedLokiSink; }
    else
      { null_sink = blackholeSink; };

  metricSinks = lib.optionalAttrs (gcCfg.enable && gcCfg.prometheus.enable) {
    grafana_cloud_prom = promRemoteWriteSink;
  };
in
{
  config = lib.mkIf (cfg.enable && aggCfg.enable) {
    assertions = [
      {
        assertion = !(gcCfg.enable && aggCfg.lokiEndpoint != null);
        message = ''
          marchyo.tracking.aggregation: cannot enable both `grafanaCloud.enable`
          and a self-hosted `lokiEndpoint`. Pick one Loki destination.
        '';
      }
    ];

    environment.systemPackages = with pkgs; [ duckdb ];

    services.prometheus.exporters.node = lib.mkIf (gcCfg.enable && gcCfg.prometheus.enable) {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 9100;
      enabledCollectors = [ "systemd" ];
    };

    systemd.services.vector.serviceConfig = lib.mkIf gcCfg.enable {
      EnvironmentFile = [ gcCfg.environmentFile ];
    };

    services.vector = {
      enable = true;
      journaldAccess = true;
      settings = {
        sources = vectorSources;

        transforms.parse = {
          type = "remap";
          inputs = parseInputs;
          source = ''
            . = parse_json!(.message)
            .host = get_hostname!()
          '';
        };

        sinks = logSinks // metricSinks;
      };
    };
  };
}
