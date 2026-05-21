{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.tracking = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the local-first self-tracking stack.

        When true, enables the full local-first self-tracking stack:
        shell history (atuin), desktop focus (ActivityWatch), editor
        heartbeats (wakapi), git activity, system file-watch,
        **kernel auditd (execve + per-user ~/.config write watch)**, log
        aggregation (Vector), and weekly LLM analysis. All collectors
        default to enabled via `lib.mkDefault`; set any sub-option to
        false to opt out.

        Screenshot capture (`marchyo.tracking.desktop.screenshots.enable`)
        defaults to false and must be enabled explicitly.

        Auditd is intentionally part of the cascade — disable it with
        `marchyo.tracking.system.auditd = false` if you don't want
        /var/log/audit growing in the background. See `marchyo.tracking.system.auditd*`
        options for tuning (backlog, rotation, ruleset lock, early-boot).

        All data stays on disk under the user's home directory or
        /var/lib. No network egress unless the aggregation sink is
        explicitly configured.
      '';
    };

    dataDir = mkOption {
      type = types.str;
      default = ".local/share/personal-data";
      description = ''
        Path (relative to the user's home) where JSONL event streams are
        written by tracking collectors.
      '';
    };

    shell = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable shell history tracking via atuin with local-only storage.
          Captures command, ns timestamp, duration, exit code, cwd, hostname
          and session. No sync server configured.
        '';
      };
    };

    desktop = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable ActivityWatch with the Wayland-native `awatcher` watcher for
          window focus and idle tracking. Default `aw-watcher-window` is X11
          only and deliberately not used.
        '';
      };

      screenshots = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable periodic JPEG screenshots via grim for later OCR and
            activity review. Sensitive windows (password managers) are
            skipped by a hyprctl classname filter.
          '';
        };

        interval = mkOption {
          type = types.str;
          default = "2min";
          example = "5min";
          description = "Interval between screenshots (systemd time span).";
        };

        retentionDays = mkOption {
          type = types.ints.positive;
          default = 30;
          description = "Number of days to retain screenshots before deletion by tmpfiles.";
        };
      };
    };

    editor = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable wakapi (self-hosted WakaTime) on 127.0.0.1 for editor
          heartbeats and install wakatime-cli system-wide.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 3000;
        description = "Port for the local wakapi service.";
      };

      plugins = {
        brave.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for Brave browser.";
        };

        chrome.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for Google Chrome.";
        };

        chromium.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for Chromium.";
        };

        firefox.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for Firefox.";
        };

        emacs.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for Emacs via wakatime-mode.";
        };

        vscode.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for VS Code.";
        };

        vscodium.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for VS Codium.";
        };

        neovim.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for Neovim via vim-wakatime.";
        };

        vim.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for Vim via vim-wakatime.";
        };

        helix.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for Helix.";
        };

        zed.enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable WakaTime tracking for Zed.";
        };
      };
    };

    git = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable a daily per-user git activity scan that aggregates commits
          across repos under ~/Developer into a JSONL stream.
        '';
      };

      scanRoot = mkOption {
        type = types.str;
        default = "Developer";
        description = "Directory (relative to \$HOME) to scan for git repositories.";
      };
    };

    system = {
      auditd = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable auditd with execve and config-change rules for process
          execution tracking. Writes to /var/log/audit.

          When `marchyo.tracking.aggregation.enable = true` is also set,
          laurel is wired in as an audisp plugin to convert audit records
          to JSON Lines under /var/log/laurel/ for the Vector pipeline.
        '';
      };

      auditdBacklogLimit = mkOption {
        type = types.ints.positive;
        default = 65536;
        description = ''
          Kernel audit ringbuffer size (`security.audit.backlogLimit`).
          Default 65536 (kernel default is 8192). Raise if `auditctl -s`
          reports lost > 0 under burst.
        '';
      };

      auditdFailureMode = mkOption {
        type = types.enum [
          "silent"
          "printk"
          "panic"
        ];
        default = "printk";
        description = ''
          Action when the audit ringbuffer overflows. Maps to
          `security.audit.failureMode`.
        '';
      };

      auditdLockRules = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Append `-e 2` to lock the loaded ruleset and make loginuid
          immutable. Requires a reboot to change rules afterwards, so
          opt-in only.
        '';
      };

      auditdMaxLogFileMB = mkOption {
        type = types.ints.positive;
        default = 128;
        description = ''
          Maximum size of a single audit log file in MB before rotation.
          Maps to auditd.conf `max_log_file`.
        '';
      };

      auditdNumLogs = mkOption {
        type = types.ints.positive;
        default = 16;
        description = ''
          Number of rotated audit log files to keep. Maps to auditd.conf
          `num_logs`. Combined with `auditdMaxLogFileMB`, this caps disk
          usage at roughly maxLogFileMB * (numLogs + 1).
        '';
      };

      auditdEarlyBoot = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Add `audit=1 audit_backlog_limit=<auditdBacklogLimit>` to the
          kernel cmdline so events from before auditd loads its rules
          are captured. Opt-in: a reboot is required to take effect.
        '';
      };

      fileWatch = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable a per-user inotify-based file change watcher covering
          ~/Developer and ~/.config, writing JSONL to the data dir.

          Note: the ~/.config watch overlaps with the auditd
          `config_changes` rule when `system.auditd = true`. The two
          observers see different things (kernel audit captures
          attributable syscalls; inotify catches in-kernel fs events the
          audit subsystem may filter), so both are kept by default.
        '';
      };
    };

    aggregation = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable the Vector log shipper reading JSONL collectors and
          (optionally) forwarding them to a Loki endpoint.
        '';
      };

      lokiEndpoint = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "http://loki.internal:3100";
        description = ''
          URL of an existing self-hosted Loki ingest endpoint. When null,
          Vector is configured with a blackhole sink (no egress) so local
          JSONL sources still validate and can be swapped later. Mutually
          exclusive with `aggregation.grafanaCloud.enable`.
        '';
      };

      grafanaCloud = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Ship Marchyo tracking data to Grafana Cloud. When true, Vector
            forwards parsed JSONL events to Grafana Cloud Loki using basic
            auth, and can optionally scrape the local node_exporter and push
            host metrics to Grafana Cloud Mimir via Prometheus remote_write.
            Credentials are read from `environmentFile` so tokens never enter
            the Nix store.
          '';
        };

        loki = {
          endpoint = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "https://logs-prod-eu-west-0.grafana.net";
            description = ''
              Grafana Cloud Loki base URL, without the `/loki/api/v1/push`
              suffix; Vector appends it.
            '';
          };

          userId = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "1234567";
            description = ''
              Grafana Cloud Loki instance/user ID, shown as "User" on the
              "Send Logs" details page.
            '';
          };
        };

        prometheus = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Also ship host metrics to Grafana Cloud Mimir via Prometheus
              remote_write. Enables `services.prometheus.exporters.node` on
              127.0.0.1:9100 and wires Vector to scrape it.
            '';
          };

          endpoint = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "https://prometheus-prod-24-prod-eu-west-2.grafana.net/api/prom/push";
            description = ''
              Grafana Cloud Mimir remote_write URL, including
              `/api/prom/push`.
            '';
          };

          userId = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "1234567";
            description = ''
              Grafana Cloud Mimir instance/user ID, shown as "User" on the
              "Send Metrics" details page.
            '';
          };
        };

        environmentFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/var/lib/marchyo/grafana-cloud.env";
          description = ''
            Path to a systemd `EnvironmentFile` loaded by the Vector service.
            Must define `GRAFANA_CLOUD_LOKI_TOKEN`, and when
            `prometheus.enable = true`, `GRAFANA_CLOUD_PROM_TOKEN`.

            The same Cloud Access Policy token can be used for both if it has
            the `logs:write` and `metrics:write` scopes. The file is read at
            service start and never enters the Nix store.
          '';
        };
      };
    };

    analysis = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable weekly aggregated activity analysis across all tracking
          sources (shell, git, desktop, editor, file changes).

          When marchyo.tracking.analysis.model is null (default), a
          stats-only org-mode report is generated. When a GGUF model path
          is provided, llama-server is started and the report includes an
          AI-generated insights section.

          This module is NOT auto-enabled by marchyo.tracking.enable and
          must be opted into explicitly.
        '';
      };

      model = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/data/models/qwen2.5-14b-q4_k_m.gguf";
        description = ''
          Filesystem path to a GGUF model file for llama-server.
          When null, analysis produces a stats-only report without LLM insights.

          The model must be in GGUF format (used by llama.cpp). Choose a
          model based on your available hardware:

          CPU-only (8 GB+ RAM):
            - Qwen2.5-3B-Instruct (Q4_K_M, ~2 GB)
            - Phi-3-mini-4k-instruct (Q4_K_M, ~2.3 GB)

          GPU with 8 GB VRAM:
            - Qwen2.5-7B-Instruct (Q4_K_M, ~4.7 GB)
            - Mistral-7B-Instruct (Q4_K_M, ~4.4 GB)

          GPU with 16 GB+ VRAM:
            - Qwen2.5-14B-Instruct (Q4_K_M, ~8.9 GB)

          Download from https://huggingface.co — search for the model name
          with "GGUF" and pick the Q4_K_M quantisation (good balance of
          quality and size). Example using curl:

            curl -L -o ~/models/qwen2.5-7b-q4_k_m.gguf \
              "https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf"

          Then set:
            marchyo.tracking.analysis.model = "/home/you/models/qwen2.5-7b-q4_k_m.gguf";
            marchyo.tracking.analysis.acceleration = "cuda"; # if using GPU
        '';
      };

      port = mkOption {
        type = types.port;
        default = 8012;
        description = "Port for the local llama-server used by analysis.";
      };

      acceleration = mkOption {
        type = types.nullOr (
          types.enum [
            "cuda"
            "rocm"
          ]
        );
        default = null;
        example = "cuda";
        description = ''
          Hardware acceleration backend for llama-server. When null the CPU
          build is used. Set to "cuda" or "rocm" for GPU inference.
        '';
      };
    };

    claudeCode = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Configure Claude Code to emit OpenTelemetry metrics and logs to an
          OTLP endpoint, such as Grafana Cloud's OTLP gateway. For every
          Marchyo user, writes ~/.claude/settings.json with an `env` block
          and exports the same variables via Home Manager session variables
          plus interactive shell init. Requires `authHeaderFile` when enabled.
        '';
      };

      otlpEndpoint = mkOption {
        type = types.str;
        default = "https://otlp-gateway-prod-eu-west-0.grafana.net/otlp";
        example = "https://otlp-gateway-prod-us-east-0.grafana.net/otlp";
        description = ''
          OTLP gateway URL. For Grafana Cloud, choose the region-specific
          gateway nearest to the stack.
        '';
      };

      protocol = mkOption {
        type = types.enum [
          "http/protobuf"
          "grpc"
        ];
        default = "http/protobuf";
        description = "OTLP transport protocol used by Claude Code.";
      };

      authHeaderFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/var/lib/marchyo/claude-code-otlp-auth";
        description = ''
          Path to a file whose contents are the value of
          `OTEL_EXPORTER_OTLP_HEADERS`, for example:

              Authorization=Basic <base64(instanceId:token)>

          The file is read at Home Manager activation and by interactive
          shell init; its contents never enter the Nix store. Keep it readable
          only by the owning user.
        '';
      };

      metricExportIntervalMs = mkOption {
        type = types.ints.positive;
        default = 10000;
        description = "Value for OTEL_METRIC_EXPORT_INTERVAL.";
      };

      logExportIntervalMs = mkOption {
        type = types.ints.positive;
        default = 5000;
        description = "Value for OTEL_LOGS_EXPORT_INTERVAL.";
      };
    };
  };
}
