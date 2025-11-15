{
  lib,
  osConfig,
  ...
}:
let
  cfg = osConfig.marchyo.keyboard;
in
{
  config = {
    # Apply marchyo keyboard configuration to Home Manager
    # This configuration is automatically picked up by Hyprland via
    # the existing code in modules/home/hyprland.nix (lines 66-78)
    home.keyboard = {
      # Concatenate layout list into comma-separated string (e.g., "us,fi")
      layout = lib.concatStringsSep "," cfg.layouts;

      # Apply keyboard variant (e.g., "intl" for us-intl)
      # When multiple layouts exist, apply variant only to first layout
      # Example: layouts=["us","fi"] variant="intl" → variant="intl,"
      variant = lib.mkIf (cfg.variant != "") (
        lib.concatStringsSep "," ([ cfg.variant ] ++ (lib.replicate ((lib.length cfg.layouts) - 1) ""))
      );

      # Apply XKB options (e.g., ["grp:win_space_toggle"])
      # These options control keyboard behavior including layout switching
      inherit (cfg) options;
    };
  };
}
