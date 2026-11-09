# Retired options (modules/nixos/options/removed.nix): a definition fails with
# the replacement hint instead of an unknown-option error.
{ helpers, ... }:
let
  inherit (helpers) testNixOSFails withTestUser;
in
{
  eval-removed-launcher-vicinae-options =
    testNixOSFails "removed-launcher-vicinae-options" "Vicinae"
      (withTestUser {
        marchyo.launcher.keybinding = "vim";
      });

  eval-removed-osd = testNixOSFails "removed-osd" "SwayOSD" (withTestUser {
    marchyo.osd.enable = false;
  });

  eval-removed-gaming = testNixOSFails "removed-gaming" "gaming bundle" (withTestUser {
    marchyo.gaming.enable = true;
  });

  eval-removed-kmscon = testNixOSFails "removed-kmscon" "kmscon" (withTestUser {
    marchyo.console.kmscon.enable = true;
  });

  eval-removed-snapshots = testNixOSFails "removed-snapshots" "Snapper" (withTestUser {
    marchyo.snapshots.enable = true;
  });

  eval-removed-shell-dev-plugins =
    testNixOSFails "removed-shell-dev-plugins" "plugin dev"
      (withTestUser {
        marchyo.shell.devPlugins.enable = true;
      });

  eval-removed-shell-bar-plugin =
    testNixOSFails "removed-shell-bar-plugin" "built-in bar"
      (withTestUser {
        marchyo.shell.barPlugin = "acme.bar";
      });

  eval-removed-ai-agents = testNixOSFails "removed-ai-agents" "not carried" (withTestUser {
    marchyo.ai.agents = [ "codex" ];
  });

  eval-removed-ai-local = testNixOSFails "removed-ai-local" "Ollama" (withTestUser {
    marchyo.ai.local.enable = true;
  });

  eval-removed-ai-crash-capture =
    testNixOSFails "removed-ai-crash-capture" "Crash capture"
      (withTestUser {
        marchyo.ai.crashCapture.enable = false;
      });

  eval-removed-console = testNixOSFails "removed-console" "Quake-style" (withTestUser {
    marchyo.console.enable = false;
  });

  eval-removed-audio-tuner = testNixOSFails "removed-audio-tuner" "speaker tuner" (withTestUser {
    marchyo.audio.tuner.enable = true;
  });

  eval-removed-camlink = testNixOSFails "removed-camlink" "Cam Link" (withTestUser {
    marchyo.hardware.camlink.enable = true;
  });

  eval-removed-slack-theme-injection =
    testNixOSFails "removed-slack-theme-injection" "Slack theme"
      (withTestUser {
        marchyo.slack.themeInjection.enable = true;
      });

  eval-removed-keyboard-legacy-binds =
    testNixOSFails "removed-keyboard-legacy-binds" "only Hyprland layout"
      (withTestUser {
        marchyo.keyboard.legacyBinds = true;
      });
}
