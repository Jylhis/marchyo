{
  lib,
  config,
  ...
}:
let
  cfg = config.marchyo.keyboard;
in
{
  config = {
    # Apply marchyo keyboard configuration to system level
    # This ensures console/TTY and X11/Wayland applications respect keyboard settings

    # XKB configuration for X11 and Wayland
    # Note: services.xserver.xkb affects both X11 and is used as source for console keymap
    services.xserver.xkb = {
      layout = lib.mkDefault (lib.concatStringsSep "," cfg.layouts);

      # Apply variant only to first layout when multiple layouts exist
      # Example: layouts=["us","fi"] variant="intl" → variant="intl,"
      variant = lib.mkDefault (
        if cfg.variant != "" then
          lib.concatStringsSep "," ([ cfg.variant ] ++ (lib.replicate ((lib.length cfg.layouts) - 1) ""))
        else
          ""
      );

      # Convert list of options to comma-separated string
      # Example: ["grp:win_space_toggle", "ctrl:nocaps"] → "grp:win_space_toggle,ctrl:nocaps"
      options = lib.mkDefault (lib.concatStringsSep "," cfg.options);
    };

    # Console (TTY) keyboard configuration
    # Use XKB configuration for console to ensure consistency between TTY and GUI
    console.useXkbConfig = true;

    # Note: In TTY/console, keyboard layout switching works differently than in GUI:
    # - The grp:win_space_toggle option is converted to a console-compatible keymap
    # - You can switch layouts using the configured key combination (e.g., both Shift keys)
    # - However, the exact key binding may differ from GUI (Super+Space → Both Shift, etc.)
    # - The first layout in cfg.layouts will be the default on boot
  };
}
