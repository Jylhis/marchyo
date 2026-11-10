# Plymouth boot-splash wiring. The theme package itself is built (and its
# installCheckPhase run) by the build-plymouth-theme-* heavy checks in
# outputs.nix; these cover the NixOS-side plumbing: the marchyo theme is
# selected by default, and modules/nixos/plymouth.nix forwards
# marchyo.theme.variant into the package .override (observable through the
# package's passthru.variant).
{ lib, ... }:
let
  themePkg = c: lib.head c.boot.plymouth.themePackages;
in
{
  refs = {
    headless = {
      eval-plymouth-default =
        c:
        c.boot.plymouth.enable
        && c.boot.plymouth.theme == "marchyo"
        && lib.length c.boot.plymouth.themePackages == 1
        && (themePkg c).pname == "plymouth-marchyo-theme"
        && (themePkg c).variant == "dark";

      # The loader menu is hidden by default (timeout 0).
      eval-plymouth-boot-menu-hidden = c: c.boot.loader.timeout == 0;
    };

    desktop-light.eval-plymouth-variant-follows-theme = c: (themePkg c).variant == "light";

    # A host can raise the loader timeout (headless-tweaks: boot.loader.timeout = 3).
    headless-tweaks.eval-plymouth-boot-timeout-override = c: c.boot.loader.timeout == 3;

    # Everything plymouth.nix sets is mkDefault — a consumer can switch it off
    # (headless-tweaks-3: boot.plymouth.enable = false).
    headless-tweaks-3.eval-plymouth-opt-out = c: !c.boot.plymouth.enable;
  };

  refConfig = {
    headless-tweaks.boot.loader.timeout = 3;
    headless-tweaks-3.boot.plymouth.enable = false;
  };
}
