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
  normalizedLayouts = map keyboardLib.normalizeLayout cfg.layouts;

  simpleLayouts = map (l: l.layout) normalizedLayouts;
  variants = map (l: l.variant) normalizedLayouts;

  hasVariants = lib.any (v: v != "") variants;
in
{
  config = {
    # fcitx5 is the authoritative input manager, but Hyprland reads home.keyboard
    # directly, so mirror the layout config here for the compositor to pick up.
    home.keyboard = lib.mkMerge [
      {
        layout = lib.concatStringsSep "," simpleLayouts;

        # Must remain a list (Hyprland joins with commas); don't convert to string.
        options = cfg.options ++ lib.optional (cfg.composeKey != null) "compose:${cfg.composeKey}";
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
