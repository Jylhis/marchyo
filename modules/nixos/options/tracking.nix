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
        shell history (atuin), desktop focus (ActivityWatch), editor heartbeats
        (wakapi), git activity, system file-watch, log aggregation (Vector), and
        weekly LLM analysis. All collectors default to enabled; set any
        sub-option to false to opt out.

        Screenshot capture (`marchyo.tracking.desktop.screenshots.enable`)
        defaults to false and must be enabled explicitly.

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
        '';
      };

      fileWatch = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable a per-user inotify-based file change watcher covering
          ~/Developer and ~/.config, writing JSONL to the data dir.
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
          URL of an existing Loki ingest endpoint. When null, Vector is
          configured with a blackhole sink (no egress) so local JSONL
          sources still validate and can be swapped later.
        '';
      };
    };

    analysis = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable local LLM-powered weekly activity analysis via llama-server
          (llama.cpp) plus a pre-mining stage (PrefixSpan). Requires a GGUF
          model file; expect multi-GB VRAM requirements for larger models.
        '';
      };

      model = mkOption {
        type = types.path;
        example = "/data/models/qwen2.5-14b-q4_k_m.gguf";
        description = "Filesystem path to a GGUF model file for llama-server.";
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
  };
}
