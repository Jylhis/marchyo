{ helpers, ... }:
let
  inherit (helpers)
    testNixOS
    testNixOSCheck
    withTestUser
    minimalConfig
    ;
in
{
  eval-minimal = testNixOS "minimal" minimalConfig;

  eval-desktop = testNixOS "desktop" (withTestUser {
    marchyo.desktop.enable = true;
  });

  eval-development = testNixOS "development" (
    minimalConfig
    // {
      marchyo.development.enable = true;
    }
  );

  # Development without desktop stays headless: docker comes on, but no Hyprland.
  eval-development-no-desktop =
    testNixOSCheck "development-no-desktop"
      (c: c.virtualisation.docker.enable == true && c.programs.hyprland.enable == false)
      (withTestUser {
        marchyo.development.enable = true;
      });

  eval-all-features = testNixOS "all-features" (withTestUser {
    marchyo = {
      desktop.enable = true;
      development.enable = true;
      media.enable = true;
      office.enable = true;
    };
  });
}
