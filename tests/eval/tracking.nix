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
}
