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

  hasVoxtypeBind = bindd: lib.any (b: lib.hasInfix "voxtype record toggle" b) bindd;
in
{
  # Dictation on: voxtype user service enabled and the Super+H toggle bound.
  eval-dictation-enabled =
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo.desktop.enable = true;
            marchyo.dictation.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          })
        ];
      };
      hm = eval.config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-dictation-enabled" (
      if
        hm.services.voxtype.enable && hasVoxtypeBind hm.wayland.windowManager.hyprland.settings.bindd
      then
        "pass"
      else
        throw "FAIL: dictation enabled but voxtype service or Super+H bind missing"
    );

  # Dictation off (default) on a desktop: no voxtype service, no dictation bind.
  eval-dictation-disabled =
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser {
            marchyo.desktop.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          })
        ];
      };
      hm = eval.config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-dictation-disabled" (
      if
        (!hm.services.voxtype.enable) && (!hasVoxtypeBind hm.wayland.windowManager.hyprland.settings.bindd)
      then
        "pass"
      else
        throw "FAIL: dictation disabled but voxtype service or Super+H bind present"
    );
}
