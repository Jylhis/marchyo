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
  # Menus default on with the desktop: both scripts are installed and the
  # power menu (SUPER+Escape) / central menu (SUPER+ALT+Space) binds exist.
  eval-menus-enabled =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-menus-enabled" (
      if
        hasBind hm "SUPER, Escape, Power menu, exec, "
        && hasBind hm "SUPER ALT, Space, System menu, exec, "
        && hasScript hm "marchyo-power-menu"
        && hasScript hm "marchyo-menu"
      then
        "pass"
      else
        throw "FAIL: desktop enabled but the menu scripts or their SUPER+Escape / SUPER+ALT+Space binds are missing"
    );

  # marchyo.menus.enable = false: config still evaluates and neither the
  # scripts nor the binds are contributed.
  eval-menus-disabled =
    let
      hm = (evalWith { marchyo.menus.enable = false; }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-menus-disabled" (
      if
        !(hasBind hm "Power menu")
        && !(hasBind hm "System menu")
        && !(hasScript hm "marchyo-power-menu")
        && !(hasScript hm "marchyo-menu")
      then
        "pass"
      else
        throw "FAIL: menus disabled but a menu bind or script is still present"
    );
}
