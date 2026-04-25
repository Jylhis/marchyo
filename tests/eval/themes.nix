{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
in
{
  eval-themes = testNixOS "themes" (withTestUser {
    marchyo.theme = {
      enable = true;
      variant = "dark";
    };
  });

  eval-themes-light = testNixOS "themes-light" (withTestUser {
    marchyo.theme = {
      enable = true;
      variant = "light";
    };
  });
}
