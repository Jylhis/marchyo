# Backlight access (modules/nixos/backlight.nix): with the desktop, the
# brightnessctl udev rules are installed and marchyo users join `video`.
{ lib, ... }:
let
  hasUdevBrightnessctl =
    cfg: lib.any (p: lib.getName p == "brightnessctl") cfg.services.udev.packages;
in
{
  refs = {
    desktop.eval-backlight-desktop =
      cfg: hasUdevBrightnessctl cfg && lib.elem "video" cfg.users.users.testuser.extraGroups;
    headless.eval-backlight-headless = cfg: !(hasUdevBrightnessctl cfg);
  };
}
