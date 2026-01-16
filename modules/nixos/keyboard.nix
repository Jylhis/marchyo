{
  lib,
  config,
  ...
}:
let
  cfg = config.marchyo.keyboard;

  # Normalize all layouts to uniform structure
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

  # Extract layout codes for XKB configuration
  simpleLayouts = map (l: l.layout) normalizedLayouts;

  # Extract variants for XKB configuration
  # Apply legacy variant option to first layout if no variant specified
  variants = lib.imap0 (
    i: l:
    if i == 0 && l.variant == "" && cfg.variant != "" then
      cfg.variant # Apply legacy variant option to first layout
    else
      l.variant
  ) normalizedLayouts;
in
{
  config = {
    assertions = [
      {
        assertion = cfg.layouts != [ ];
        message = "marchyo.keyboard.layouts cannot be empty. Specify at least one layout.";
      }
    ];

    warnings = lib.optionals (cfg.variant != "") [
      "marchyo.keyboard.variant is deprecated. Use { layout = \"us\"; variant = \"intl\"; } in marchyo.keyboard.layouts instead."
    ];
    # XKB fallback configuration for TTY/console and login screen
    # fcitx5 manages input in the desktop environment, but TTY needs XKB
    services.xserver.xkb = {
      # Configure all layouts (including those with IME) for basic TTY support
      layout = lib.mkDefault (lib.concatStringsSep "," simpleLayouts);

      # Configure variants for each layout
      variant = lib.mkDefault (lib.concatStringsSep "," variants);

      # Convert list of options to comma-separated string
      options = lib.mkDefault (lib.concatStringsSep "," cfg.options);
    };

    # Enable console keyboard layout switching in TTY
    # This allows Super+Space to work in virtual consoles (TTY1-TTY6)
    # Note: IME functionality is not available in TTY (fcitx5 requires graphical environment)
    console.useXkbConfig = true;
  };
}
