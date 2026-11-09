# marchyo.fonts.cleanUserCache: the activation entry that rebuilds a stale
# fontconfig user cache exists by default and disappears when disabled.
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

  activationOf = extra: (evalWith extra).config.home-manager.users.testuser.home.activation;
in
{
  eval-fontconfig-cache-default-rebuilds =
    let
      script = (activationOf { }).marchyoFontconfigCache.data or null;
    in
    pkgs.writeText "eval-fontconfig-cache-default-rebuilds" (
      if script != null && lib.hasInfix "fc-cache" script then
        "pass"
      else
        throw "FAIL: marchyo.fonts.cleanUserCache should install a fc-cache activation entry by default"
    );

  eval-fontconfig-cache-disabled-omitted =
    let
      a =
        (evalWith {
          home-manager.users.testuser.marchyo.fonts.cleanUserCache = false;
        }).config.home-manager.users.testuser.home.activation;
    in
    pkgs.writeText "eval-fontconfig-cache-disabled-omitted" (
      if !a ? marchyoFontconfigCache then
        "pass"
      else
        throw "FAIL: marchyo.fonts.cleanUserCache = false must omit the activation entry"
    );
}
