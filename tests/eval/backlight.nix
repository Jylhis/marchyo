# Backlight access (modules/nixos/backlight.nix): with the desktop, the
# brightnessctl udev rules are installed and marchyo users join `video`.
{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser;

  hasUdevBrightnessctl =
    cfg: lib.any (p: lib.getName p == "brightnessctl") cfg.services.udev.packages;
in
{
  eval-backlight-desktop =
    testNixOSCheck "backlight-desktop"
      (cfg: hasUdevBrightnessctl cfg && lib.elem "video" cfg.users.users.testuser.extraGroups)
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  eval-backlight-headless =
    testNixOSCheck "backlight-headless" (cfg: !(hasUdevBrightnessctl cfg))
      (withTestUser {
        marchyo.desktop.enable = false;
      });
}
