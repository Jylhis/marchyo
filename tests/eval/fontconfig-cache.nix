# marchyo.fonts.cleanUserCache: the activation entry that rebuilds a stale
# fontconfig user cache exists by default and disappears when disabled
# (desktop-off).
{ lib, ... }:
let
  activationOf = c: c.home-manager.users.testuser.home.activation;
in
{
  refs = {
    desktop = {
      eval-fontconfig-cache-default-rebuilds =
        c:
        let
          script = (activationOf c).marchyoFontconfigCache.data or null;
        in
        if script != null && lib.hasInfix "fc-cache" script then
          true
        else
          "marchyo.fonts.cleanUserCache should install a fc-cache activation entry by default";
    };

    desktop-off = {
      eval-fontconfig-cache-disabled-omitted =
        c:
        let
          a = c.home-manager.users.testuser.home.activation;
        in
        if !a ? marchyoFontconfigCache then
          true
        else
          "marchyo.fonts.cleanUserCache = false must omit the activation entry";
    };
  };

  refConfig.desktop-off.home-manager.users.testuser.marchyo.fonts.cleanUserCache = false;
}
