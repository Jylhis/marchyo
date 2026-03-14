{
  lib,
  osConfig,
  ...
}:
let
  cfg = osConfig.marchyo.keyboard;

  # Normalize all layouts to uniform structure (same as NixOS module)
  normalizedLayouts = map (
    layout:
    if builtins.isString layout then
      {
        inherit layout;
        variant = "";
        ime = null;
        label = null;
      }
    else
      layout
  ) cfg.layouts;

  # Extract layout codes for niri compatibility
  simpleLayouts = map (l: l.layout) normalizedLayouts;

  # Extract variants (empty string if no variant)
  variants = map (l: l.variant) normalizedLayouts;

  # Check if any layout has a non-empty variant
  hasVariants = lib.any (v: v != "") variants;
in
{
  config = {
    # Configure home.keyboard for niri compatibility
    # Note: fcitx5 is the authoritative input manager, but niri reads home.keyboard
    # This configuration is automatically picked up by niri via
    # the existing code in modules/home/niri.nix
    home.keyboard = lib.mkMerge [
      {
        # Concatenate layout list into comma-separated string (e.g., "us,fi,cn")
        layout = lib.concatStringsSep "," simpleLayouts;

        # Apply XKB options as list (niri reads them from home.keyboard)
        # Must remain a list - don't convert to string
        inherit (cfg) options;
      }
      # Only set variant if at least one layout has a variant
      # This avoids issues with empty string lists
      (lib.mkIf hasVariants {
        # Provide variants as comma-separated string
        # Note: Empty strings in the list preserve position mapping to layouts
        # Example: "intl," means first layout has "intl" variant, second has default
        variant = lib.concatStringsSep "," variants;
      })
    ];
  };
}
