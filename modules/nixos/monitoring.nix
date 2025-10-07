{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    mkIf
    mkMerge
    mkDefault
    types
    ;
  cfg = config.marchyo.monitoring;
in
{
  options.marchyo.monitoring = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable monitoring stack with Prometheus, Grafana, and Loki.
        Provides comprehensive system metrics, visualization, and log aggregation.
      '';
    };

    enableAlertmanager = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable Prometheus Alertmanager for alert routing and management.
        Requires monitoring.enable to be true.
      '';
    };

    grafana = {
      port = mkOption {
        type = types.port;
        default = 3000;
        example = 8080;
        description = ''
          Port on which Grafana web interface will be available.
        '';
      };

      domain = mkOption {
        type = types.str;
        default = "localhost";
        example = "monitoring.example.com";
        description = ''
          Domain name for Grafana. Used for setting the root URL.
          Set to your actual domain if running behind a reverse proxy.
        '';
      };

      enableAnonymousAccess = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable anonymous read-only access to Grafana dashboards.
          Useful for public monitoring displays or internal kiosks.
          Disable for production environments requiring authentication.
        '';
      };
    };

    prometheus = {
      port = mkOption {
        type = types.port;
        default = 9090;
        example = 9091;
        description = ''
          Port on which Prometheus web interface will be available.
        '';
      };

      retention = mkOption {
        type = types.str;
        default = "15d";
        example = "30d";
        description = ''
          How long to retain Prometheus metrics data.
          Uses Prometheus time duration format (e.g., "15d", "1y", "4w").
        '';
      };
    };

    loki = {
      port = mkOption {
        type = types.port;
        default = 3100;
        example = 3101;
        description = ''
          Port on which Loki will be available.
        '';
      };

      retentionPeriod = mkOption {
        type = types.int;
        default = 168; # 7 days in hours
        example = 720; # 30 days in hours
        description = ''
          How long to retain log data in Loki (in hours).
          Default is 168 hours (7 days).
        '';
      };

      maxStorageSize = mkOption {
        type = types.str;
        default = "1GB";
        example = "5GB";
        description = ''
          Maximum storage size for Loki data.
          Uses standard size units (KB, MB, GB, TB).
        '';
      };
    };
  };

  config = mkMerge [
    # Prometheus Configuration
    (mkIf cfg.enable {
      services.prometheus = {
        enable = true;
        inherit (cfg.prometheus) port;
        retentionTime = cfg.prometheus.retention;

        # Export Prometheus metrics for collection
        exporters = {
          # Node exporter provides system-level metrics
          # CPU, memory, disk, network, etc.
          node = {
            enable = true;
            enabledCollectors = [
              "systemd" # systemd units and services
              "processes" # process statistics
              "cpu" # CPU statistics
              "diskstats" # disk I/O statistics
              "filesystem" # filesystem usage
              "loadavg" # load average
              "meminfo" # memory statistics
              "netdev" # network device statistics
            ];
            port = 9100;
          };
        };

        # Define what Prometheus should scrape
        scrapeConfigs = [
          {
            job_name = "node-exporter";
            static_configs = [
              {
                targets = [ "localhost:9100" ];
                labels = {
                  alias = config.networking.hostName;
                };
              }
            ];
          }
          {
            job_name = "prometheus";
            static_configs = [
              {
                targets = [ "localhost:${toString cfg.prometheus.port}" ];
              }
            ];
          }
          {
            job_name = "loki";
            static_configs = [
              {
                targets = [ "localhost:${toString cfg.loki.port}" ];
              }
            ];
          }
        ];
      };
    })

    # Loki Log Aggregation
    (mkIf cfg.enable {
      services.loki = {
        enable = true;
        configuration = {
          # Server configuration
          server = {
            http_listen_port = cfg.loki.port;
            grpc_listen_port = 9096;
          };

          # Authentication (disabled for local use)
          auth_enabled = false;

          # Ingester configuration - handles incoming log streams
          ingester = {
            # Lifecycle configuration
            lifecycler = {
              address = "127.0.0.1";
              ring = {
                kvstore = {
                  store = "inmemory";
                };
                replication_factor = 1;
              };
              final_sleep = "0s";
            };
            # How often to flush chunks to storage
            chunk_idle_period = "5m";
            chunk_retain_period = "30s";
          };

          # Schema configuration - defines how data is stored
          schema_config = {
            configs = [
              {
                from = "2024-01-01";
                store = "tsdb";
                object_store = "filesystem";
                schema = "v13";
                index = {
                  prefix = "index_";
                  period = "24h";
                };
              }
            ];
          };

          # Storage configuration - where data is persisted
          storage_config = {
            tsdb_shipper = {
              active_index_directory = "/var/lib/loki/tsdb-index";
              cache_location = "/var/lib/loki/tsdb-cache";
            };
            filesystem = {
              directory = "/var/lib/loki/chunks";
            };
          };

          # Limits configuration
          limits_config = {
            reject_old_samples = true;
            reject_old_samples_max_age = "168h"; # 7 days
            ingestion_rate_mb = 16;
            ingestion_burst_size_mb = 24;
          };

          # Table manager - handles data retention
          table_manager = {
            retention_deletes_enabled = true;
            retention_period = "${toString cfg.loki.retentionPeriod}h";
          };

          # Compactor - manages data compaction
          compactor = {
            working_directory = "/var/lib/loki/compactor";
            compaction_interval = "10m";
            retention_enabled = true;
            retention_delete_delay = "2h";
            retention_delete_worker_count = 150;
          };
        };
      };

      # Promtail - ships logs to Loki
      services.promtail = {
        enable = true;
        configuration = {
          server = {
            http_listen_port = 9080;
            grpc_listen_port = 0;
          };

          # Send logs to local Loki instance
          clients = [
            {
              url = "http://localhost:${toString cfg.loki.port}/loki/api/v1/push";
            }
          ];

          # Define what logs to collect
          scrape_configs = [
            {
              job_name = "journal";
              journal = {
                max_age = "12h";
                labels = {
                  job = "systemd-journal";
                  host = config.networking.hostName;
                };
              };
              relabel_configs = [
                {
                  source_labels = [ "__journal__systemd_unit" ];
                  target_label = "unit";
                }
                {
                  source_labels = [ "__journal__hostname" ];
                  target_label = "hostname";
                }
                {
                  source_labels = [ "__journal_priority_keyword" ];
                  target_label = "level";
                }
              ];
            }
          ];
        };
      };
    })

    # Grafana Visualization
    (mkIf cfg.enable {
      services.grafana = {
        enable = true;

        settings = {
          # Server configuration
          server = {
            http_port = cfg.grafana.port;
            inherit (cfg.grafana) domain;
            root_url = "http://${cfg.grafana.domain}:${toString cfg.grafana.port}";
          };

          # Anonymous access configuration
          "auth.anonymous" = mkIf cfg.grafana.enableAnonymousAccess {
            enabled = true;
            org_role = "Viewer"; # Read-only access
          };

          # Security settings
          security = {
            # Generate this with: openssl rand -base64 32
            # For production, override with secrets management
            admin_user = mkDefault "admin";
            admin_password = mkDefault "admin";
          };

          # Analytics - disable for privacy
          analytics = {
            reporting_enabled = false;
            check_for_updates = false;
          };
        };

        # Provision datasources automatically
        provision = {
          enable = true;

          # Add Prometheus as default datasource
          datasources.settings.datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              url = "http://localhost:${toString cfg.prometheus.port}";
              isDefault = true;
              jsonData = {
                timeInterval = "30s";
              };
            }
            {
              name = "Loki";
              type = "loki";
              access = "proxy";
              url = "http://localhost:${toString cfg.loki.port}";
              jsonData = {
                maxLines = 1000;
              };
            }
          ];

          # Dashboard provisioning from /etc/grafana-dashboards
          dashboards.settings.providers = [
            {
              name = "default";
              options.path = "/etc/grafana-dashboards";
              disableDeletion = false;
              updateIntervalSeconds = 10;
              allowUiUpdates = true;
              type = "file";
            }
          ];
        };
      };

      # Create dashboard directory
      environment.etc."grafana-dashboards/.keep" = {
        text = ''
          This directory is for Grafana dashboard JSON files.
          Place your dashboard JSON files here and they will be automatically provisioned.
        '';
      };
    })

    # Alertmanager (optional)
    (mkIf (cfg.enable && cfg.enableAlertmanager) {
      services.prometheus.alertmanager = {
        enable = true;
        port = 9093;

        # Basic configuration - customize as needed
        configuration = {
          route = {
            receiver = "default";
            group_by = [
              "alertname"
              "cluster"
              "service"
            ];
            group_wait = "30s";
            group_interval = "5m";
            repeat_interval = "4h";
          };

          receivers = [
            {
              name = "default";
              # Add notification channels here
              # Example: email, slack, webhook, etc.
            }
          ];
        };
      };

      # Add Alertmanager to Prometheus scrape configs
      services.prometheus.scrapeConfigs = [
        {
          job_name = "alertmanager";
          static_configs = [
            {
              targets = [ "localhost:9093" ];
            }
          ];
        }
      ];

      # Configure Prometheus to use Alertmanager
      services.prometheus.alertmanagers = [
        {
          static_configs = [
            {
              targets = [ "localhost:9093" ];
            }
          ];
        }
      ];
    })

    # Firewall configuration (commented out by default)
    # Uncomment and adjust if you need external access
    # (mkIf cfg.enable {
    #   networking.firewall.allowedTCPPorts = [
    #     cfg.prometheus.port
    #     cfg.grafana.port
    #     cfg.loki.port
    #   ];
    # })
  ];
}
