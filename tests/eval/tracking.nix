{ helpers, ... }:
let
  inherit (helpers) testNixOS testNixOSCheck withTestUser;
in
{
  eval-tracking-minimal = testNixOS "tracking-minimal" (withTestUser {
    marchyo.tracking.enable = true;
  });

  eval-tracking-shell = testNixOS "tracking-shell" (withTestUser {
    marchyo.tracking = {
      enable = true;
      shell.enable = true;
    };
  });

  eval-tracking-git = testNixOS "tracking-git" (withTestUser {
    marchyo.tracking = {
      enable = true;
      git.enable = true;
    };
  });

  eval-tracking-editor-wakatime = testNixOS "tracking-editor-wakatime" (withTestUser {
    marchyo.tracking = {
      enable = true;
      editor.enable = true;
    };
    marchyo.users.testuser.wakatimeApiKey = "waka_test_00000000-0000-0000-0000-000000000000";
  });

  # Analysis module — stats-only (no model).
  eval-tracking-analysis = testNixOS "tracking-analysis" (withTestUser {
    marchyo.tracking = {
      enable = true;
      analysis.enable = true;
    };
  });

  # Analysis module — with LLM model configured.
  eval-tracking-analysis-with-model = testNixOS "tracking-analysis-model" (withTestUser {
    marchyo.tracking = {
      enable = true;
      analysis.enable = true;
      analysis.model = "/data/models/test.gguf";
    };
  });

  # Full cascade does NOT auto-enable analysis — assert the value, don't just
  # evaluate an identical-to-minimal config.
  eval-tracking-no-auto-analysis =
    testNixOSCheck "tracking-no-auto-analysis" (c: c.marchyo.tracking.analysis.enable == false)
      (withTestUser {
        marchyo.tracking.enable = true;
      });

  # Editor plugins auto-detect from defaults.
  eval-tracking-editor-plugins = testNixOS "tracking-editor-plugins" (withTestUser {
    marchyo.tracking = {
      enable = true;
      editor.enable = true;
    };
    marchyo.desktop.enable = true;
    marchyo.defaults.browser = "firefox";
    marchyo.defaults.editor = "vscode";
    marchyo.defaults.terminalEditor = "neovim";
  });

  # Editor plugins with explicit overrides.
  eval-tracking-editor-plugins-override = testNixOS "tracking-editor-plugins-override" (withTestUser {
    marchyo.tracking = {
      enable = true;
      editor = {
        enable = true;
        plugins.chrome.enable = true;
        plugins.emacs.enable = true;
      };
    };
  });

  # Auditd path with a configured user (exercises execve rules, the per-user
  # config_changes watch, the new tuning options, and the laurel + Vector
  # pipeline since aggregation cascades on too).
  eval-tracking-auditd = testNixOS "tracking-auditd" (withTestUser {
    marchyo.tracking = {
      enable = true;
      system.auditd = true;
    };
  });

  # Auditd path with empty marchyo.users — guards against the silent
  # degradation where the per-user config_changes rule list collapses to
  # []. minimalConfig is used directly (no withTestUser) so marchyo.users
  # stays empty.
  eval-tracking-auditd-no-users =
    let
      inherit (helpers) minimalConfig;
    in
    testNixOS "tracking-auditd-no-users" (
      minimalConfig
      // {
        marchyo.tracking = {
          enable = true;
          system.auditd = true;
        };
      }
    );

  # Grafana Cloud aggregation (Loki + Prometheus remote_write).
  eval-tracking-grafana-cloud = testNixOS "tracking-grafana-cloud" (withTestUser {
    marchyo.tracking = {
      enable = true;
      aggregation = {
        enable = true;
        grafanaCloud = {
          enable = true;
          environmentFile = "/var/lib/marchyo/grafana-cloud.env";
          loki = {
            endpoint = "https://logs-prod-eu-west-0.grafana.net";
            userId = "1234567";
          };
          prometheus = {
            enable = true;
            endpoint = "https://prometheus-prod-24-prod-eu-west-2.grafana.net/api/prom/push";
            userId = "1234567";
          };
        };
      };
    };
  });

  # Claude Code OTLP telemetry.
  eval-tracking-claude-code = testNixOS "tracking-claude-code" (withTestUser {
    marchyo.tracking = {
      enable = true;
      claudeCode = {
        enable = true;
        authHeaderFile = "/var/lib/marchyo/claude-code-otlp-auth";
      };
    };
  });

  # Negative: Grafana Cloud and self-hosted Loki are mutually exclusive.
  eval-tracking-grafana-cloud-loki-conflict =
    let
      inherit (helpers) testNixOSFails;
    in
    testNixOSFails "tracking-grafana-cloud-loki-conflict" "cannot enable both" (withTestUser {
      marchyo.tracking = {
        enable = true;
        aggregation = {
          enable = true;
          lokiEndpoint = "http://loki.internal:3100";
          grafanaCloud = {
            enable = true;
            environmentFile = "/var/lib/marchyo/grafana-cloud.env";
            loki = {
              endpoint = "https://logs-prod-eu-west-0.grafana.net";
              userId = "1234567";
            };
          };
        };
      };
    });

  # Negative: Claude Code telemetry requires a secret header file.
  eval-tracking-claude-code-missing-auth =
    let
      inherit (helpers) testNixOSFails;
    in
    testNixOSFails "tracking-claude-code-missing-auth" "authHeaderFile" (withTestUser {
      marchyo.tracking = {
        enable = true;
        claudeCode.enable = true;
      };
    });
}
