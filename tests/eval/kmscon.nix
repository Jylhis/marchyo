{ helpers, ... }:
let
  inherit (helpers) testNixOS withTestUser;
in
{
  # kmscon is off by default, so the reference console stays the kernel VT.
  eval-kmscon-default-off = testNixOS "kmscon-default-off" (withTestUser { });

  # Default kmscon wiring: inherits XKB, derives font size from fontScale.
  eval-kmscon = testNixOS "kmscon" (withTestUser {
    marchyo.console.kmscon.enable = true;
  });

  # Hardware acceleration pulls the GL stack in via the overridable default,
  # satisfying the upstream hwaccel -> hardware.graphics.enable assertion.
  eval-kmscon-hwaccel = testNixOS "kmscon-hwaccel" (withTestUser {
    marchyo.console.kmscon = {
      enable = true;
      hwaccel = true;
    };
  });

  # Custom font, scrollback, and an extraConfig key that overrides a derived
  # default all evaluate.
  eval-kmscon-tuned = testNixOS "kmscon-tuned" (withTestUser {
    marchyo.console.kmscon = {
      enable = true;
      fontName = "JetBrainsMono Nerd Font";
      scrollbackLines = 50000;
      extraConfig = {
        palette = "solarized";
        font-dpi = 96;
      };
    };
  });
}
