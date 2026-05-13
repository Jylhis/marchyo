{
  lib,
  config,
  ...
}:
let
  cfg = config.marchyo.keyboard;
  keyboardLib = import ../generic/keyboard-lib.nix;
  normalizedLayouts = map keyboardLib.normalizeLayout cfg.layouts;

  # Extract layout codes for XKB configuration
  simpleLayouts = map (l: l.layout) normalizedLayouts;

  # Extract variants for XKB configuration
  # The deprecated cfg.variant, when set, takes precedence on the first layout
  # so existing configs that only set the legacy option keep working even when
  # the default first layout now ships with its own variant (e.g. altgr-intl).
  variants = lib.imap0 (
    i: l:
    if i == 0 && cfg.variant != "" then
      cfg.variant
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
      options = lib.mkDefault (
        lib.concatStringsSep "," (
          cfg.options ++ lib.optional (cfg.composeKey != null) "compose:${cfg.composeKey}"
        )
      );
    };

    # Enable console keyboard layout switching in TTY
    # This allows Super+Space to work in virtual consoles (TTY1-TTY6)
    # Note: IME functionality is not available in TTY (fcitx5 requires graphical environment)
    console.useXkbConfig = true;
  };
}
