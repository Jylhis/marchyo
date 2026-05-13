{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
in
{
  eval-themes = testNixOS "themes" (withTestUser {
    marchyo.theme = {
      enable = true;
      variant = "dark";
      # Custom scheme override (must exist in pkgs.base16-schemes).
      scheme = "nord";
    };
  });

  eval-themes-light = testNixOS "themes-light" (withTestUser {
    marchyo.theme = {
      enable = true;
      variant = "light";
    };
  });

  # Paper (light) variant with desktop — catches dark-only regressions in
  # waybar / hyprland / mako / hyprlock / fzf / starship / etc.
  eval-themes-paper = testNixOS "themes-paper" (withTestUser {
    marchyo = {
      desktop.enable = true;
      theme = {
        enable = true;
        variant = "light";
      };
    };
  });
}
