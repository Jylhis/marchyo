{ lib, ... }:
let
  inherit (lib) mkOption types;

  userOpts =
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          example = false;
          description = ''
            If set to false, the user account will not have any Marchyo stuff.
          '';
        };

        name = mkOption {
          type = types.str;
          default = name;
          description = ''
            The name of the user account.
            Use `users.users.{name}.name` to reference it.
          '';
        };
        fullname = mkOption {
          type = types.str;
          description = "Your full name";
        };
        email = mkOption {
          type = types.str;
          description = "Your email address";
        };

        wakatimeApiKey = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = ''
            WakaTime API key for editor heartbeat tracking.
            When set together with marchyo.tracking.editor.enable, a
            ~/.wakatime.cfg is generated and WAKATIME_API_KEY is exported.
          '';
        };
      };
    };
in
{
  options.marchyo = {
    users = mkOption {
      default = { };
      type = with types; attrsOf (submodule userOpts);
      description = ''
        Marchyo user configuration.
        Defines users with associated metadata like fullname and email.
      '';
    };

    defaults = {
      browser = mkOption {
        type = types.nullOr (
          types.enum [
            "brave"
            "google-chrome"
            "firefox"
            "chromium"
          ]
        );
        default = "google-chrome";
        example = "firefox";
        description = ''
          Default web browser. Installed automatically when desktop is enabled
          and registered as the system default for HTTP/HTTPS links.
          Set to null to skip browser management.
        '';
      };

      editor = mkOption {
        type = types.nullOr (
          types.enum [
            "emacs"
            "jotain"
            "vscode"
            "vscodium"
            "zed"
          ]
        );
        default = "jotain";
        example = "vscode";
        description = ''
          Default graphical text editor ($VISUAL). Installed automatically when
          desktop is enabled and registered as the system default for plain text
          files. Set to null to skip editor management.
          "jotain" is externally managed (like "gmail"/"outlook" for email):
          package installation and VISUAL are handled by programs.jotain.
        '';
      };

      terminalEditor = mkOption {
        type = types.nullOr (
          types.enum [
            "emacs"
            "jotain"
            "neovim"
            "helix"
            "nano"
          ]
        );
        default = "jotain";
        example = "neovim";
        description = ''
          Default terminal text editor ($EDITOR). Installed automatically when
          desktop is enabled. Set to null to skip terminal editor management.
          "jotain" is externally managed (like "gmail"/"outlook" for email):
          package installation and EDITOR are handled by programs.jotain.
        '';
      };

      videoPlayer = mkOption {
        type = types.nullOr (
          types.enum [
            "mpv"
            "vlc"
            "celluloid"
          ]
        );
        default = "mpv";
        example = "vlc";
        description = ''
          Default video player. Installed automatically when desktop is enabled
          and registered as the system default for video MIME types.
          Set to null to skip video player management.
        '';
      };

      audioPlayer = mkOption {
        type = types.nullOr (
          types.enum [
            "mpv"
            "vlc"
            "amberol"
          ]
        );
        default = "mpv";
        example = "vlc";
        description = ''
          Default audio player for local files. Installed automatically when
          desktop is enabled and registered as the system default for audio
          MIME types. Set to null to skip audio player management.
        '';
      };

      musicPlayer = mkOption {
        type = types.nullOr (types.enum [ "spotify" ]);
        default = "spotify";
        example = "spotify";
        description = ''
          Default music streaming player. Installed automatically when desktop
          is enabled. Set to null to skip music player management.
        '';
      };

      fileManager = mkOption {
        type = types.nullOr (
          types.enum [
            "nautilus"
            "thunar"
          ]
        );
        default = "nautilus";
        example = "thunar";
        description = ''
          Default graphical file manager. Installed automatically when desktop
          is enabled and registered as the system default for directory MIME
          types. Set to null to skip file manager management.
        '';
      };

      terminalFileManager = mkOption {
        type = types.nullOr (
          types.enum [
            "yazi"
            "ranger"
            "lf"
          ]
        );
        default = "yazi";
        example = "ranger";
        description = ''
          Default terminal file manager. Installed automatically when desktop
          is enabled. Set to null to skip terminal file manager management.
        '';
      };

      imageEditor = mkOption {
        type = types.nullOr (
          types.enum [
            "pinta"
            "gimp"
            "krita"
          ]
        );
        default = "pinta";
        example = "gimp";
        description = ''
          Default image editor. Installed automatically when desktop is enabled.
          Set to null to skip image editor management.
        '';
      };

      email = mkOption {
        type = types.nullOr (
          types.enum [
            "gmail"
            "thunderbird"
            "outlook"
          ]
        );
        default = "gmail";
        example = "thunderbird";
        description = ''
          Default email client. "gmail" and "outlook" are web apps opened in
          the browser (no package installed). "thunderbird" installs the native
          client. Set to null to skip email management.
        '';
      };
    };

    desktop = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable desktop environment (Hyprland, Wayland, fonts, etc.)";
      };
    };

    development = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable development tools (Docker, buildah, gh, etc.)";
      };
    };

    media = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable media applications (Spotify, MPV, etc.)";
      };
    };

    office = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable office applications (LibreOffice, Papers, etc.)";
      };
    };

    performance = {
      disableMitigations = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Disable CPU vulnerability mitigations (Spectre, Meltdown, etc.) for maximum performance.
          WARNING: This reduces security. Only enable on trusted single-user workstations
          where maximum performance is required (e.g., gaming, benchmarking).
          Do NOT enable if running untrusted code or containers.
        '';
      };
    };

    graphics = {
      vendors = mkOption {
        type = types.listOf (
          types.enum [
            "intel"
            "amd"
            "nvidia"
          ]
        );
        default = [ ];
        example = [
          "intel"
          "nvidia"
        ];
        description = ''
          GPU vendors present in the system.
          - "intel": Intel integrated graphics (iGPU)
          - "amd": AMD GPUs (integrated or discrete)
          - "nvidia": NVIDIA discrete GPUs

          For hybrid graphics laptops, specify both vendors (e.g., ["intel" "nvidia"]).
          When empty, Intel packages are applied on x86_64 for backward compatibility.

          Find your GPU with: lspci | grep -E 'VGA|3D'
        '';
      };

      nvidia = {
        open = mkOption {
          type = types.bool;
          default = true;
          description = ''
            Use NVIDIA's open-source kernel modules.
            Recommended for Turing (RTX 20xx) and newer GPUs.
            Required for RTX 50xx series.
            Set to false for older GPUs (Maxwell, Pascal, Volta).
          '';
        };

        powerManagement = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable experimental power management for NVIDIA GPUs.
            May improve battery life on laptops but can cause issues on some systems.
          '';
        };
      };

      prime = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable NVIDIA PRIME for hybrid graphics laptops.
            Requires both an integrated GPU (intel or amd) and nvidia in vendors.
          '';
        };

        intelBusId = mkOption {
          type = types.str;
          default = "";
          example = "PCI:0:2:0";
          description = ''
            PCI bus ID of the Intel integrated GPU.
            Find with: lspci | grep -E 'VGA|3D' | grep Intel
            Format: PCI:bus:device:function (convert hex to decimal)
          '';
        };

        amdgpuBusId = mkOption {
          type = types.str;
          default = "";
          example = "PCI:6:0:0";
          description = ''
            PCI bus ID of the AMD integrated GPU.
            Find with: lspci | grep -E 'VGA|3D' | grep AMD
            Format: PCI:bus:device:function (convert hex to decimal)
          '';
        };

        nvidiaBusId = mkOption {
          type = types.str;
          default = "";
          example = "PCI:1:0:0";
          description = ''
            PCI bus ID of the NVIDIA discrete GPU.
            Find with: lspci | grep -E 'VGA|3D' | grep NVIDIA
            Format: PCI:bus:device:function (convert hex to decimal)
          '';
        };

        mode = mkOption {
          type = types.enum [
            "offload"
            "sync"
            "reverse-sync"
          ];
          default = "offload";
          description = ''
            PRIME render mode:
            - "offload": On-demand rendering (default, power efficient).
              Use `nvidia-offload <command>` to run apps on dGPU.
            - "sync": Always use discrete GPU (best performance, more power).
            - "reverse-sync": iGPU for display, dGPU for compute.
          '';
        };
      };
    };

    timezone = mkOption {
      type = types.str;
      default = "Europe/Zurich";
      example = "America/New_York";
      description = "System timezone";
    };

    defaultLocale = mkOption {
      type = types.str;
      default = "en_US.UTF-8";
      example = "de_DE.UTF-8";
      description = "System default locale";
    };

    theme = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Stylix theming system";
      };

      variant = mkOption {
        type = types.enum [
          "light"
          "dark"
        ];
        default = "dark";
        example = "light";
        description = ''
          Theme variant preference (light or dark).
          Used to select default color scheme when scheme is null:
          - "dark" defaults to nord
          - "light" defaults to nord-light
        '';
      };

      scheme = mkOption {
        type = types.nullOr (types.either types.str types.attrs);
        default = null;
        example = "dracula";
        description = ''
          Color scheme to use. Can be:
          - A scheme name from nix-colors (e.g., "dracula", "gruvbox-dark-medium")
          - A custom color scheme name (e.g., "modus-vivendi-tinted", "modus-operandi-tinted")
          - A custom attribute set defining base00-base0F colors
          - null to use default scheme based on variant
        '';
      };
    };

    keyboard = {
      layouts = mkOption {
        type = types.listOf (
          types.either types.str (
            types.submodule {
              options = {
                layout = mkOption {
                  type = types.str;
                  description = "Keyboard layout code (e.g., 'us', 'fi', 'cn', 'jp', 'kr')";
                  example = "us";
                };

                variant = mkOption {
                  type = types.str;
                  default = "";
                  example = "intl";
                  description = ''
                    Layout variant (e.g., 'intl', 'dvorak').
                    Leave empty for default variant.
                  '';
                };

                ime = mkOption {
                  type = types.nullOr (
                    types.enum [
                      "pinyin"
                      "mozc"
                      "hangul"
                      "unicode"
                    ]
                  );
                  default = null;
                  example = "pinyin";
                  description = ''
                    Input method engine to activate when this layout is selected.
                    - pinyin: Chinese input (requires fcitx5-chinese-addons)
                    - mozc: Japanese input (requires fcitx5-mozc)
                    - hangul: Korean input (requires fcitx5-hangul)
                    - unicode: Unicode character picker
                    When null, layout uses direct keyboard input.
                  '';
                };

                label = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  example = "中文";
                  description = "Display label for this input method (auto-generated if null)";
                };
              };
            }
          )
        );
        default = [
          {
            layout = "us";
            variant = "altgr-intl";
          }
          "fi"
        ];
        example = lib.literalExpression ''
          [
            "us"                                    # Simple keyboard layout
            "fi"                                    # Simple keyboard layout
            { layout = "us"; variant = "intl"; }   # US international with dead keys
            { layout = "cn"; ime = "pinyin"; }     # Chinese with Pinyin IME
            { layout = "jp"; ime = "mozc"; }       # Japanese with Mozc IME
            { layout = "kr"; ime = "hangul"; }     # Korean with Hangul IME
          ]
        '';
        description = ''
          List of keyboard layouts and input methods.

          Each entry can be:
          - A string: Simple keyboard layout code (e.g., "us", "fi", "de")
          - An attribute set: Advanced configuration with optional IME

          Examples:
          - "us" → US English keyboard
          - { layout = "cn"; ime = "pinyin"; } → Chinese keyboard with Pinyin input
          - { layout = "us"; variant = "intl"; } → US international with dead keys

          When an entry includes 'ime', the input method engine will be automatically
          activated when you switch to that layout using Super+Space.

          All inputs are managed by fcitx5 for consistent behavior across the desktop.
          Basic layouts are also configured in XKB for TTY/console compatibility.
        '';
      };

      variant = mkOption {
        type = types.str;
        default = "";
        example = "intl";
        description = ''
          DEPRECATED: Use layout variant in marchyo.keyboard.layouts instead.
          Example: { layout = "us"; variant = "intl"; }

          This option only applies to the first layout when using simple string list.
          It is kept for backward compatibility but may be removed in a future release.
        '';
      };

      options = mkOption {
        type = types.listOf types.str;
        default = [ "grp:win_space_toggle" ]; # Note: "Win" = Super key in XKB terminology
        example = [
          "grp:win_space_toggle"
          "ctrl:swapcaps"
          "compose:ralt"
        ];
        description = ''
          XKB keyboard options for fcitx5 keyboard layouts.
          Default enables Super+Space for layout/input method switching.

          Common options:
          - grp:win_space_toggle: Use Super+Space to switch inputs (Win = Super key)
          - ctrl:swapcaps: Swap Caps Lock and Left Control
          - ctrl:nocaps: Make Caps Lock another Control key
          - caps:escape: Map Caps Lock to Escape
          - compose:ralt: Use Right Alt as Compose key

          For a complete list of available options, see:
          - NixOS manual: https://nixos.org/manual/nixos/stable/index.html#sec-xserver-keyboard
          - XKB configuration: /usr/share/X11/xkb/rules/base.lst (on any Linux system)
          - xkeyboard-config docs: https://www.freedesktop.org/wiki/Software/XKeyboardConfig/
        '';
      };

      composeKey = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = "menu";
        example = "rwin";
        description = ''
          Sets the XKB Compose key for typing special characters.
          Common values:
          - menu: Menu key (default)
          - ralt: Right Alt key
          - rwin: Right Super/Windows key
          - caps: Caps Lock key
          - null: Disable compose key

          Note: `ralt` is intentionally not the default because the default
          layout `us(altgr-intl)` needs Right Alt as AltGr (ISO_Level3_Shift)
          for AltGr-based typography (e.g., AltGr+- → en dash, AltGr+Shift+- →
          em dash). If you change layouts to a plain `us` you can set this
          back to `"ralt"`.

          Set to null to disable the compose key entirely.
        '';
      };

      autoActivateIME = mkOption {
        type = types.bool;
        default = true;
        example = false;
        description = ''
          Automatically activate IME when switching to a layout with ime specified.

          When true (default): Switching to Chinese layout automatically activates Pinyin.
          When false: User must manually trigger IME with imeTriggerKey after switching layout.

          Recommended: true (provides seamless language switching experience)
        '';
      };

      imeTriggerKey = mkOption {
        type = types.listOf types.str;
        default = [ "Super+I" ];
        example = [
          "Super+I"
          "Alt+grave"
        ];
        description = ''
          Key combinations to manually toggle IME activation on/off.

          Use this to disable IME for a layout that has IME configured,
          or to activate Unicode picker independent of layout.

          Default: Super+I toggles IME for current input method
        '';
      };
    };

    tracking = {
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
              auth, and (optionally) scrapes the local node_exporter and
              pushes host metrics to Grafana Cloud Mimir via Prometheus
              remote_write. Credentials are read from
              `aggregation.grafanaCloud.environmentFile` so tokens never
              enter the Nix store.
            '';
          };

          loki = {
            endpoint = mkOption {
              type = types.str;
              example = "https://logs-prod-eu-west-0.grafana.net";
              description = ''
                Grafana Cloud Loki base URL (without the
                `/loki/api/v1/push` suffix; Vector appends it).
              '';
            };

            userId = mkOption {
              type = types.str;
              example = "1234567";
              description = ''
                Grafana Cloud Loki instance/user ID (the numeric "User"
                shown on the "Send Logs" details page).
              '';
            };
          };

          prometheus = {
            enable = mkOption {
              type = types.bool;
              default = false;
              description = ''
                Also ship host metrics to Grafana Cloud Mimir via
                Prometheus remote_write. Enables
                `services.prometheus.exporters.node` on 127.0.0.1:9100 and
                wires Vector to scrape it.
              '';
            };

            endpoint = mkOption {
              type = types.str;
              example = "https://prometheus-prod-24-prod-eu-west-2.grafana.net/api/prom/push";
              description = ''
                Grafana Cloud Mimir remote_write URL (the full path,
                including `/api/prom/push`).
              '';
            };

            userId = mkOption {
              type = types.str;
              example = "1234567";
              description = ''
                Grafana Cloud Mimir instance/user ID (the numeric "User"
                shown on the "Send Metrics" details page).
              '';
            };
          };

          environmentFile = mkOption {
            type = types.path;
            example = "/var/lib/marchyo/grafana-cloud.env";
            description = ''
              Path to a systemd `EnvironmentFile` loaded by the Vector
              service. Must define:

                  GRAFANA_CLOUD_LOKI_TOKEN=<token>

              and, when `prometheus.enable = true`:

                  GRAFANA_CLOUD_PROM_TOKEN=<token>

              The same Cloud Access Policy token can be used for both if
              it has the `logs:write` and `metrics:write` scopes. The file
              is read at service start and never enters the Nix store.
            '';
          };
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

      claudeCode = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Configure Claude Code to emit OpenTelemetry metrics and logs
            to an OTLP endpoint (e.g. Grafana Cloud's OTLP gateway). For
            every Marchyo user, writes ~/.claude/settings.json with an
            `env` block and exports the same variables via
            `home.sessionVariables` plus interactive shell init so both
            launcher- and shell-started Claude Code sessions inherit the
            telemetry config. Requires `authHeaderFile` to be set.
          '';
        };

        otlpEndpoint = mkOption {
          type = types.str;
          default = "https://otlp-gateway-prod-eu-west-0.grafana.net/otlp";
          example = "https://otlp-gateway-prod-us-east-0.grafana.net/otlp";
          description = ''
            Grafana Cloud OTLP gateway URL. Region-specific; pick the
            gateway nearest to your Grafana Cloud stack.
          '';
        };

        protocol = mkOption {
          type = types.enum [
            "http/protobuf"
            "grpc"
          ];
          default = "http/protobuf";
          description = ''
            OTLP transport protocol used by Claude Code
            (OTEL_EXPORTER_OTLP_PROTOCOL).
          '';
        };

        authHeaderFile = mkOption {
          type = types.path;
          example = "/var/lib/marchyo/claude-code-otlp-auth";
          description = ''
            Path to a file whose contents are the value of
            OTEL_EXPORTER_OTLP_HEADERS, e.g.

                Authorization=Basic <base64(instanceId:token)>

            The file is read at home-manager activation and by interactive
            shell init; its contents never enter the Nix store. Keep it
            readable only by the owning user (chmod 0600).
          '';
        };

        metricExportIntervalMs = mkOption {
          type = types.ints.positive;
          default = 10000;
          description = ''
            Value for OTEL_METRIC_EXPORT_INTERVAL (milliseconds between
            metric exports).
          '';
        };

        logExportIntervalMs = mkOption {
          type = types.ints.positive;
          default = 5000;
          description = ''
            Value for OTEL_LOGS_EXPORT_INTERVAL (milliseconds between log
            exports).
          '';
        };
      };
    };

    inputMethod = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          REMOVED: This option has been removed in favor of marchyo.keyboard.layouts.

          Please migrate your configuration:

          OLD:
            marchyo.inputMethod.enable = true;
            marchyo.inputMethod.enableCJK = true;
            marchyo.keyboard.layouts = ["us" "fi"];

          NEW:
            marchyo.keyboard.layouts = [
              "us"
              "fi"
              { layout = "cn"; ime = "pinyin"; }  # For Chinese input
              # { layout = "jp"; ime = "mozc"; }  # For Japanese input
              # { layout = "kr"; ime = "hangul"; }  # For Korean input
            ];

          See CLAUDE.md for complete documentation.
        '';
      };

      triggerKey = mkOption {
        type = types.listOf types.str;
        default = [
          "Super+I"
          "Zenkaku_Hankaku"
          "Hangul"
        ];
        example = [
          "Alt+grave"
          "Super+I"
        ];
        description = ''
          INERT: This option has no effect. Use marchyo.keyboard.imeTriggerKey instead.

          This option is kept only to avoid evaluation errors for consumers who
          haven't migrated yet. It will be removed in a future release.
        '';
      };

      enableCJK = mkOption {
        type = types.bool;
        default = true;
        description = ''
          INERT: This option has no effect. Add CJK layouts to marchyo.keyboard.layouts instead.

          Example:
            marchyo.keyboard.layouts = [
              "us"
              { layout = "cn"; ime = "pinyin"; }  # Chinese
              { layout = "jp"; ime = "mozc"; }    # Japanese
              { layout = "kr"; ime = "hangul"; }  # Korean
            ];

          This option is kept only to avoid evaluation errors for consumers who
          haven't migrated yet. It will be removed in a future release.
        '';
      };
    };
  };
}
