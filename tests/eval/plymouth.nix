# Plymouth boot-splash wiring. The theme package itself is built (and its
# installCheckPhase run) by the build-plymouth-theme-* checks added in
# outputs.nix; these eval tests cover the NixOS-side plumbing: the marchyo
# theme is selected by default, and modules/nixos/plymouth.nix forwards
# marchyo.theme.variant into the package .override (observable through the
# package's passthru.variant).
{ helpers, lib, ... }:
let
  inherit (helpers) testNixOSCheck withTestUser;
  themePkg = c: lib.head c.boot.plymouth.themePackages;
in
{
  eval-plymouth-default = testNixOSCheck "plymouth-default" (
    c:
    c.boot.plymouth.enable
    && c.boot.plymouth.theme == "marchyo"
    && lib.length c.boot.plymouth.themePackages == 1
    && (themePkg c).pname == "plymouth-marchyo-theme"
    && (themePkg c).variant == "dark"
  ) (withTestUser { });

  eval-plymouth-variant-follows-theme =
    testNixOSCheck "plymouth-variant-follows-theme" (c: (themePkg c).variant == "light")
      (withTestUser {
        marchyo.theme.variant = "light";
      });

  # The loader menu is hidden by default (timeout 0), and a host can raise it.
  eval-plymouth-boot-menu-hidden = testNixOSCheck "plymouth-boot-menu-hidden" (
    c: c.boot.loader.timeout == 0
  ) (withTestUser { });

  eval-plymouth-boot-timeout-override =
    testNixOSCheck "plymouth-boot-timeout-override" (c: c.boot.loader.timeout == 3)
      (withTestUser {
        boot.loader.timeout = 3;
      });

  # Everything plymouth.nix sets is mkDefault — a consumer can switch it off.
  eval-plymouth-opt-out =
    testNixOSCheck "plymouth-opt-out" (c: !c.boot.plymouth.enable)
      (withTestUser {
        boot.plymouth.enable = false;
      });
}
