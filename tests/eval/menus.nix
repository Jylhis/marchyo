{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

  evalWith =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };

  binds = hm: hm.wayland.windowManager.hyprland.settings.bindd or [ ];
  hasBind = hm: s: lib.any (b: lib.hasInfix s b) (binds hm);
  scriptNames = hm: map (p: p.name or "") (hm.home.packages or [ ]);
  hasScript = hm: n: lib.any (lib.hasInfix n) (scriptNames hm);
in
{
  # Menus default on with the desktop: the binds dispatch the marchyo CLI
  # menus and the gum tool closure is installed (the marchyo-menu /
  # marchyo-power-menu scripts were absorbed into the CLI).
  eval-menus-enabled =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-menus-enabled" (
      if
        hasBind hm "SUPER, Escape, Power menu, exec, $terminal --class=org.omarchy.terminal -e marchyo menu power"
        && hasBind hm "SUPER ALT, Space, System menu, exec, $terminal --class=org.omarchy.terminal -e marchyo menu"
        && hasScript hm "gum"
        && !(hasScript hm "marchyo-power-menu")
      then
        "pass"
      else
        throw "FAIL: desktop enabled but the CLI menu binds or the gum tool closure are missing"
    );

  # marchyo.menus.enable = false: config still evaluates and the menu binds
  # are gone. (gum itself may remain — utilities.nix installs it for the
  # reminder/transcode prompts, which have their own toggles; probe the
  # menu-only wiremix instead.)
  eval-menus-disabled =
    let
      hm = (evalWith { marchyo.menus.enable = false; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-menus-disabled" (
      if !(hasBind hm "Power menu") && !(hasBind hm "System menu") && !(hasScript hm "wiremix") then
        "pass"
      else
        throw "FAIL: menus disabled but a menu bind or the menu tool closure is still present"
    );
}
