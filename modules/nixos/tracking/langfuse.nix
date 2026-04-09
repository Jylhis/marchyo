# Langfuse: local LLM observability and tracing.
#
# Runs the Langfuse server as a Docker container backed by a dedicated
# PostgreSQL database. The web UI and API are available at
# http://localhost:<port>. All data stays on disk; no network egress.
{
  config,
  lib,
  ...
}:
let
  cfg = config.marchyo.tracking;
  lfCfg = cfg.langfuse;
in
{
  config = lib.mkIf (cfg.enable && lfCfg.enable) {
    # Dedicated PostgreSQL database for Langfuse.
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "langfuse" ];
      ensureUsers = [
        {
          name = "langfuse";
          ensureDBOwnership = true;
        }
      ];
      # Allow the Docker container to connect over TCP with peer-like trust.
      authentication = lib.mkAfter ''
        host langfuse langfuse 127.0.0.1/32 trust
        host langfuse langfuse ::1/128 trust
      '';
    };

    # Langfuse OCI container on the host network so it can reach PostgreSQL
    # at 127.0.0.1 and expose its UI on the configured port.
    virtualisation.oci-containers = {
      backend = "docker";
      containers.langfuse = {
        image = "langfuse/langfuse:${lfCfg.imageTag}";
        environment = {
          DATABASE_URL = "postgresql://langfuse@127.0.0.1:5432/langfuse";
          NEXTAUTH_URL = "http://localhost:${toString lfCfg.port}";
          NEXTAUTH_SECRET = "marchyo-langfuse-local-only";
          SALT = "marchyo-langfuse-local-salt";
          PORT = toString lfCfg.port;
          TELEMETRY_ENABLED = "false";
          LANGFUSE_ENABLE_EXPERIMENTAL_FEATURES = "false";
        };
        extraOptions = [ "--network=host" ];
      };
    };

    # Ensure the container starts after PostgreSQL is ready.
    systemd.services.docker-langfuse = {
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
    };
  };
}
