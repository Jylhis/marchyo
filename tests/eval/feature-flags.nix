{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser minimalConfig;
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

  eval-all-features = testNixOS "all-features" (withTestUser {
    marchyo = {
      desktop.enable = true;
      development.enable = true;
      media.enable = true;
      office.enable = true;
    };
  });

  # Worktrunk is auto-enabled by the development feature flag.
  eval-worktrunk = testNixOS "worktrunk" (withTestUser {
    marchyo.development.enable = true;
  });
}
