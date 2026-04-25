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
        "us"
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

        When an entry includes 'ime', the input method engine will be automatically
        activated when you switch to that layout using Super+Space.

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
      default = [ "grp:win_space_toggle" ]; # Note: "Win" = Super key in XKB terminology
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
      default = "ralt";
      example = "rwin";
      description = ''
        Sets the XKB Compose key for typing special characters.
        Common values:
        - ralt: Right Alt key (default)
        - rwin: Right Super/Windows key
        - caps: Caps Lock key
        - menu: Menu key
        - null: Disable compose key

        Set to null to disable the compose key entirely.
      '';
    };

    autoActivateIME = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = ''
        Automatically activate IME when switching to a layout with ime specified.

        When true (default): Switching to Chinese layout automatically activates Pinyin.
        When false: User must manually trigger IME with imeTriggerKey after switching layout.

        Recommended: true (provides seamless language switching experience)
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
        Key combinations to manually toggle IME activation on/off.

        Use this to disable IME for a layout that has IME configured,
        or to activate Unicode picker independent of layout.

        Default: Super+I toggles IME for current input method
      '';
    };
  };
}
