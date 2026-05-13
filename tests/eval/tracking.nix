{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
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

  # Exercises inline PrefixSpan + Ollama wiring.
  eval-tracking-analysis = testNixOS "tracking-analysis" (withTestUser {
    marchyo.tracking = {
      enable = true;
      analysis.enable = true;
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
}
