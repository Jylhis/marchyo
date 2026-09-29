{
  lib,
  config,
  ...
}:
let
  cfg = config.marchyo.keyboard;
  keyboardLib = import ../generic/keyboard-lib.nix;
  normalizedLayouts = map keyboardLib.normalizeLayout cfg.layouts;

  simpleLayouts = map (l: l.layout) normalizedLayouts;

  # The deprecated cfg.variant, when set, takes precedence on the first layout
  # so existing configs that only set the legacy option keep working even when
  # the default first layout now ships with its own variant (e.g. altgr-intl).
  variants = lib.imap0 (
    i: l: if i == 0 && cfg.variant != "" then cfg.variant else l.variant
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
    # fcitx5 manages input in the desktop environment, but TTY/console needs XKB.
    services.xserver.xkb = {
      layout = lib.mkDefault (lib.concatStringsSep "," simpleLayouts);

      variant = lib.mkDefault (lib.concatStringsSep "," variants);

      options = lib.mkDefault (
        lib.concatStringsSep "," (
          cfg.options ++ lib.optional (cfg.composeKey != null) "compose:${cfg.composeKey}"
        )
      );
    };

    # Lets Super+Space switch layouts in virtual consoles (TTY1-TTY6).
    # IME is not available in TTY (fcitx5 requires a graphical environment).
    console.useXkbConfig = true;
  };
}
