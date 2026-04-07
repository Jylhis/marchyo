# Aggregation: Vector log shipper + DuckDB for ad-hoc analytics.
#
# Tails the JSONL event streams in each configured marchyo user's data
# directory and either forwards them to a Loki endpoint or drops them into
# a local blackhole sink when no endpoint is configured.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  aggCfg = cfg.aggregation;
  mUsers = builtins.attrNames config.marchyo.users;

  jsonlPaths = map (u: "/home/${u}/${cfg.dataDir}/*.jsonl") mUsers;

  lokiSink = {
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

  blackholeSink = {
    type = "blackhole";
    inputs = [ "parse" ];
    print_interval_secs = 3600;
  };
in
{
  config = lib.mkIf (cfg.enable && aggCfg.enable) {
    environment.systemPackages = with pkgs; [ duckdb ];

    services.vector = {
      enable = true;
      journaldAccess = true;
      settings = {
        sources.activity_logs = {
          type = "file";
          include = jsonlPaths;
          read_from = "beginning";
        };
        transforms.parse = {
          type = "remap";
          inputs = [ "activity_logs" ];
          source = ''
            . = parse_json!(.message)
            .host = get_hostname!()
          '';
        };
        sinks = if aggCfg.lokiEndpoint != null then { loki = lokiSink; } else { null_sink = blackholeSink; };
      };
    };
  };
}
