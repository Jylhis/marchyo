{ helpers, ... }:
let
  inherit (helpers) testNixOS minimalConfig;
in
{
  eval-slack = testNixOS "slack" (
    minimalConfig
    // {
      programs.slack.enable = true;
    }
  );

  eval-slack-theme-injection = testNixOS "slack-theme-injection" (
    minimalConfig
    // {
      programs.slack.enable = true;
      marchyo.slack.themeInjection.enable = true;
    }
  );

  eval-slack-settings = testNixOS "slack-settings" (
    minimalConfig
    // {
      programs.slack = {
        enable = true;
        settings = {
          DefaultSignInTeam = "example";
          HardwareAcceleration = false;
        };
      };
    }
  );

  eval-logitech = testNixOS "logitech" (
    minimalConfig
    // {
      marchyo.hardware.logitech.enable = true;
    }
  );
}
