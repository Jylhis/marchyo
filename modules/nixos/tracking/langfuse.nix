# Langfuse: local LLM observability and tracing.
#
# Runs the Langfuse server as a native NixOS service backed by a dedicated
# PostgreSQL database. The web UI and API are available at
# http://localhost:<port>. All data stays on disk; no network egress.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  lfCfg = cfg.langfuse;

  langfuse = pkgs.callPackage ../../../packages/langfuse/package.nix { };

  migrationScript = pkgs.writeShellScript "langfuse-migrate" ''
    set -eu
    DB_URL="$DATABASE_URL"

    # Run cleanup SQL before migrations (matches upstream entrypoint.sh)
    ${langfuse}/bin/langfuse-db-cleanup --url "$DB_URL" || true

    # Apply Prisma migrations
    ${langfuse}/bin/langfuse-migrate
  '';
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
    };

    # Langfuse systemd service running the Next.js standalone server.
    systemd.services.langfuse = {
      description = "Langfuse LLM observability server";
      after = [
        "postgresql.service"
        "network.target"
      ];
      requires = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        DATABASE_URL = "postgresql://langfuse@localhost/langfuse?host=/run/postgresql";
        DIRECT_URL = "postgresql://langfuse@localhost/langfuse?host=/run/postgresql";
        NEXTAUTH_URL = "http://localhost:${toString lfCfg.port}";
        NEXTAUTH_SECRET = "marchyo-langfuse-local-only";
        SALT = "marchyo-langfuse-local-salt";
        PORT = toString lfCfg.port;
        HOSTNAME = "127.0.0.1";
        NODE_ENV = "production";
        NEXT_TELEMETRY_DISABLED = "1";
        TELEMETRY_ENABLED = "false";
        LANGFUSE_ENABLE_EXPERIMENTAL_FEATURES = "false";
        # ClickHouse is optional for v2; disable its migration
        LANGFUSE_AUTO_CLICKHOUSE_MIGRATION_DISABLED = "true";
      };

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        User = "langfuse";
        Group = "langfuse";
        StateDirectory = "langfuse";
        ExecStartPre = "+${migrationScript}";
        ExecStart = "${langfuse}/bin/langfuse-server";
        Restart = "on-failure";
        RestartSec = 5;

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [ "/var/lib/langfuse" ];
      };
    };

    users.users.langfuse = {
      isSystemUser = true;
      group = "langfuse";
      description = "Langfuse service user";
    };

    users.groups.langfuse = { };
  };
}
