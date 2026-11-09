{
  lib,
  osConfig ? { },
  ...
}:
let
  cfg =
    (osConfig.marchyo or { }).keyboard or {
      layouts = [ ];
      options = [ ];
      composeKey = null;
    };
  keyboardLib = import ../generic/keyboard-lib.nix;
  composeOption = (import ../../lib/xkb-compose.nix).optionFor cfg.composeKey;
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  # The Shift+Caps compose option lives in /etc/xkb, outside xkeyboard-config.
  # Without XKB_CONFIG_EXTRA_PATH, Hyprland cannot compile the keymap at all
  # and loses every layout, so the session env carries it as well as the
  # NixOS session variables.
  shiftCaps = cfg.composeKey == "shift-caps";
  xkbExtraPath = "/etc/xkb";
  normalizedLayouts = map keyboardLib.normalizeLayout cfg.layouts;

  simpleLayouts = map (l: l.layout) normalizedLayouts;
  variants = map (l: l.variant) normalizedLayouts;

  hasVariants = lib.any (v: v != "") variants;
in
{
  config = {
    wayland.windowManager.hyprland.settings.env = lib.mkIf shiftCaps [
      (hlua.env "XKB_CONFIG_EXTRA_PATH" xkbExtraPath)
    ];
    # uwsm reads this before it starts the compositor.
    xdg.configFile."uwsm/env-hyprland" = lib.mkIf shiftCaps {
      text = "export XKB_CONFIG_EXTRA_PATH=${xkbExtraPath}\n";
    };

    # fcitx5 is the authoritative input manager, but Hyprland reads home.keyboard
    # directly, so mirror the layout config here for the compositor to pick up.
    home.keyboard = lib.mkMerge [
      {
        layout = lib.concatStringsSep "," simpleLayouts;

        # Must remain a list (Hyprland joins with commas); don't convert to string.
        options = cfg.options ++ lib.optional (composeOption != null) composeOption;
      }
      # Skip variant entirely unless one layout has a variant, to avoid empty-string-list issues.
      (lib.mkIf hasVariants {
        # Empty strings preserve position mapping to layouts, e.g. "intl,"
        # means the first layout has the "intl" variant and the second the default.
        variant = lib.concatStringsSep "," variants;
      })
    ];
  };
}
