{ helpers, lib, ... }:
let
  inherit (helpers) testNixOS testNixOSCheck withTestUser;
in
{
  # CLI module: defaults to enabled, installs `marchyo` system-wide.
  eval-cli-default = testNixOS "cli-default" (withTestUser { });

  # CLI module: explicitly disabled (no marchyo binary installed).
  eval-cli-disabled = testNixOS "cli-disabled" (withTestUser {
    marchyo.cli.enable = false;
  });

  # CLI module: marchyoCliState merges into config.marchyo.* with mkDefault.
  # Note: marchyoCliState is a top-level option (not under marchyo.*) on
  # purpose to avoid a self-cycle in cli-state.nix.
  eval-cli-with-state = testNixOS "cli-with-state" (withTestUser {
    marchyoCliState = {
      theme.variant = "light";
    };
  });

  # With desktop + cli enabled (both default true for cli), the Hyprland
  # session restores CLI runtime overrides at startup.
  eval-cli-runtime-restore =
    testNixOSCheck "cli-runtime-restore"
      (
        cfg:
        builtins.any (
          e: lib.hasInfix "marchyo runtime restore" (toString e)
        ) cfg.home-manager.users.testuser.wayland.windowManager.hyprland.settings.exec-once
      )
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # marchyoCliState can append CLI-managed webapps additively: extraApps
  # entries land in the generated launcher set without replacing the
  # default marchyo.webapps.apps list.
  eval-cli-webapp-extra =
    testNixOSCheck "cli-webapp-extra"
      (
        cfg:
        let
          apps = cfg.marchyo.webapps.apps ++ cfg.marchyo.webapps.extraApps;
        in
        builtins.any (a: a.name == "Figma") apps && builtins.any (a: a.name == "GitHub") apps
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyoCliState.webapps.extraApps = [
          {
            name = "Figma";
            url = "https://figma.com/";
            key = "F";
          }
        ];
      });

  # cli.enable = false must also drop the exec-once entry.
  eval-cli-disabled-no-restore =
    testNixOSCheck "cli-disabled-no-restore"
      (
        cfg:
        !(builtins.any (
          e: lib.hasInfix "marchyo runtime restore" (toString e)
        ) cfg.home-manager.users.testuser.wayland.windowManager.hyprland.settings.exec-once)
      )
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.cli.enable = false;
      });
}
