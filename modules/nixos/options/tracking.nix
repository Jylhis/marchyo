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
