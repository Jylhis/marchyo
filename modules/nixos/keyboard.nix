{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.keyboard;
  keyboardLib = import ../generic/keyboard-lib.nix;
  xkbCompose = import ../../lib/xkb-compose.nix;
  shiftCaps = cfg.composeKey == "shift-caps";
  fnlock = if cfg.fnMode == "function" then "1" else "0";
  fnmode = if cfg.fnMode == "function" then "2" else "1";
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
      {
        assertion = !(shiftCaps && xkbCompose.remapsCaps cfg.options);
        message = ''
          marchyo.keyboard.composeKey = "shift-caps" redefines Caps Lock and undoes the
          Caps Lock remap in marchyo.keyboard.options. Pick another composeKey.
        '';
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
          cfg.options ++ lib.optional (cfg.composeKey != null && !shiftCaps) "compose:${cfg.composeKey}"
        )
      );
    };

    # Lets Super+Space switch layouts in virtual consoles (TTY1-TTY6).
    # IME is not available in TTY (fcitx5 requires a graphical environment).
    console.useXkbConfig = true;

    # The custom option lives outside xkeyboard-config, so only libxkbcommon
    # clients (Hyprland) can resolve it, through XKB_CONFIG_EXTRA_PATH.
    environment.etc = lib.mkIf shiftCaps { "xkb".source = xkbCompose.tree pkgs; };
    environment.sessionVariables = lib.mkIf shiftCaps { XKB_CONFIG_EXTRA_PATH = "/etc/xkb"; };

    # fnmode 1 = media keys first, 2 = F-keys first (hid_apple).
    boot.extraModprobeConfig = lib.mkIf (cfg.fnMode != null) ''
      options hid_apple fnmode=${fnmode}
      options hid_asus fnlock_default=${fnlock}
      options asus_wmi fnlock_default=${fnlock}
    '';
  };
}
