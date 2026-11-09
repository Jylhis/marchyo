{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.keyboard = {
    layouts = mkOption {
      type = types.listOf (
        types.either types.str (
          types.submodule {
            options = {
              layout = mkOption {
                type = types.str;
                description = "Keyboard layout code (e.g., 'us', 'fi', 'cn', 'jp', 'kr')";
                example = "us";
              };

              variant = mkOption {
                type = types.str;
                default = "";
                example = "intl";
                description = ''
                  Layout variant (e.g., 'intl', 'dvorak').
                  Leave empty for default variant.
                '';
              };

              ime = mkOption {
                type = types.nullOr (
                  types.enum [
                    "pinyin"
                    "mozc"
                    "hangul"
                    "chewing"
                    "cangjie"
                    "unicode"
                  ]
                );
                default = null;
                example = "pinyin";
                description = ''
                  Input method engine to activate when this layout is selected.
                  - pinyin: Chinese input (requires fcitx5-chinese-addons)
                  - mozc: Japanese input (requires fcitx5-mozc)
                  - hangul: Korean input (requires fcitx5-hangul)
                  - chewing: Traditional Chinese Zhuyin input (requires fcitx5-chewing)
                  - cangjie: Hong Kong Cangjie 5 input (requires fcitx5-table-extra)
                  - unicode: Unicode character picker
                  When null, layout uses direct keyboard input.
                '';
              };

              label = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "中文";
                description = "Display label for this input method (auto-generated if null)";
              };
            };
          }
        )
      );
      default = [
        {
          layout = "us";
          variant = "altgr-intl";
        }
        "fi"
      ];
      example = lib.literalExpression ''
        [
          "us"                                    # Simple keyboard layout
          "fi"                                    # Simple keyboard layout
          { layout = "us"; variant = "intl"; }   # US international with dead keys
          { layout = "cn"; ime = "pinyin"; }     # Chinese with Pinyin IME
          { layout = "jp"; ime = "mozc"; }       # Japanese with Mozc IME
          { layout = "kr"; ime = "hangul"; }     # Korean with Hangul IME
          { layout = "us"; ime = "chewing"; }    # Zhuyin on a US keyboard
          { layout = "us"; ime = "cangjie"; }    # Cangjie 5 on a US keyboard
        ]
      '';
      description = ''
        List of keyboard layouts and input methods.

        Each entry can be:
        - A string: Simple keyboard layout code (e.g., "us", "fi", "de")
        - An attribute set: Advanced configuration with optional IME

        Examples:
        - "us" → US English keyboard
        - { layout = "cn"; ime = "pinyin"; } → Chinese keyboard with Pinyin input
        - { layout = "us"; variant = "intl"; } → US international with dead keys

        When an entry includes 'ime', the engine is added to the fcitx5 group
        after the keyboard layouts. Input starts in the keyboard layout (Latin);
        a lone Shift toggles between the engine and Latin, and the keys in
        'imeTriggerKey' cycle through the layouts and then the engines.

        All inputs are managed by fcitx5 for consistent behavior across the desktop.
        Basic layouts are also configured in XKB for TTY/console compatibility.
      '';
    };

    variant = mkOption {
      type = types.str;
      default = "";
      example = "intl";
      description = ''
        DEPRECATED: Use layout variant in marchyo.keyboard.layouts instead.
        Example: { layout = "us"; variant = "intl"; }

        This option only applies to the first layout when using simple string list.
        It is kept for backward compatibility but may be removed in a future release.
      '';
    };

    options = mkOption {
      type = types.listOf types.str;
      default = [ "grp:win_space_toggle" ];
      example = [
        "grp:win_space_toggle"
        "ctrl:swapcaps"
        "compose:ralt"
      ];
      description = ''
        XKB keyboard options for fcitx5 keyboard layouts.
        Default enables Super+Space for layout/input method switching.

        Common options:
        - grp:win_space_toggle: Use Super+Space to switch inputs (Win = Super key)
        - ctrl:swapcaps: Swap Caps Lock and Left Control
        - ctrl:nocaps: Make Caps Lock another Control key
        - caps:escape: Map Caps Lock to Escape
        - compose:ralt: Use Right Alt as Compose key

        For a complete list of available options, see:
        - NixOS manual: https://nixos.org/manual/nixos/stable/index.html#sec-xserver-keyboard
        - XKB configuration: /usr/share/X11/xkb/rules/base.lst (on any Linux system)
        - xkeyboard-config docs: https://www.freedesktop.org/wiki/Software/XKeyboardConfig/
      '';
    };

    composeKey = mkOption {
      type = types.nullOr types.nonEmptyStr;
      default = "menu";
      example = "shift-caps";
      description = ''
        Sets the XKB Compose key for typing special characters.
        Common values:
        - menu: Menu key (default)
        - shift-caps: Shift+Caps Lock (Caps Lock keeps its normal job).
          Applies to Hyprland only: the console and X keep no compose key.
          It cannot be combined with an option that remaps Caps Lock
          (ctrl:swapcaps, ctrl:nocaps, caps:escape)
        - ralt: Right Alt key
        - rwin: Right Super/Windows key
        - caps: Caps Lock key
        - null: Disable compose key

        Note: `ralt` is intentionally not the default because the default
        layout `us(altgr-intl)` needs Right Alt as AltGr (ISO_Level3_Shift)
        for AltGr-based typography (e.g., AltGr+- → en dash, AltGr+Shift+- →
        em dash). If you change layouts to a plain `us` you can set this
        back to `"ralt"`.

        Set to null to disable the compose key entirely.
      '';
    };

    autoActivateIME = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Start with the input method engine active (fcitx5 ActiveByDefault).

        When false (default): input starts in Latin and the engine is
        switched on with a lone Shift or imeTriggerKey.
        When true: the engine is active as soon as a text field gets focus.
      '';
    };

    imeTriggerKey = mkOption {
      type = types.listOf types.str;
      default = [ "Super+I" ];
      example = [
        "Super+I"
        "Alt+grave"
      ];
      description = ''
        Key combinations that cycle through the keyboard layouts and then
        the input method engines of the fcitx5 group, and back to the first
        layout. They are added to the fcitx5 trigger keys beside Super+Space.

        Default: Super+I
      '';
    };

    fnMode = mkOption {
      type = types.nullOr (
        types.enum [
          "media"
          "function"
        ]
      );
      default = null;
      example = "media";
      description = ''
        What the top row of the keyboard sends by default, for drivers that
        keep Fn-lock on the host (hid_apple, hid_asus, asus_wmi):
        - media: media keys; Fn gives F1-F12
        - function: F1-F12; Fn gives the media keys
        - null: leave the firmware or driver default

        Keyboards that keep Fn-lock in their firmware ignore this option.
        The hid_asus and asus_wmi drivers read it at load time, so it takes
        effect at the next boot.
      '';
    };

    backlight.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Bind the keyboard backlight keys (XF86KbdBrightnessUp/Down,
        XF86KbdLightOnOff, and Ctrl plus the display brightness keys) to
        `marchyo brightness --keyboard`. Does nothing on machines without a
        `*kbd_backlight*` LED. systemd-backlight saves and restores the level
        across reboots, so no extra service is needed.
      '';
    };
  };
}
