# The menu binds and their tool closure; desktop-off sets
# marchyo.menus.enable = false.
{ helpers, lib, ... }:
let
  inherit (helpers) hyprHasBind hyprEntriesText;
  binds = hm: hm.wayland.windowManager.hyprland.settings.bind or [ ];
  hasBind = hm: hyprHasBind (binds hm);
  # Substring search over every rendered bind, for "no bind mentions X" checks.
  hasBindText = hm: s: lib.hasInfix s (hyprEntriesText (binds hm));
  scriptNames = hm: map (p: p.name or "") (hm.home.packages or [ ]);
  hasScript = hm: n: lib.any (lib.hasInfix n) (scriptNames hm);
in
{
  refs = {
    desktop = {
      # Menus default on with the desktop: the binds open the shell's command
      # menu (the gum TUI binds apply without the shell) and the gum tool closure is installed (the marchyo-menu /
      # marchyo-power-menu scripts were absorbed into the CLI).
      eval-menus-enabled =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if
          hasBind hm "SUPER + Escape" "marchyo:menu.system"
          && hasBind hm "SUPER + ALT + SPACE" "marchyo:menu"
          && hasScript hm "gum"
          && !(hasScript hm "marchyo-power-menu")
        then
          true
        else
          "desktop enabled but the CLI menu binds or the gum tool closure are missing";
    };

    desktop-off = {
      # marchyo.menus.enable = false: config still evaluates and the menu binds
      # are gone. (gum itself may remain — utilities.nix installs it for the
      # reminder/transcode prompts, which have their own toggles; probe the
      # menu-only wiremix instead.)
      eval-menus-disabled =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if
          !(hasBindText hm "Power menu") && !(hasBindText hm "System menu") && !(hasScript hm "wiremix")
        then
          true
        else
          "menus disabled but a menu bind or the menu tool closure is still present";
    };
  };

  refConfig.desktop-off.marchyo.menus.enable = false;
}
