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
}
