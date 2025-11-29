{ lib, ... }:
let
  inherit (lib) mkOption types;
  # cfg = config.marchyo;

  userOpts =
    { name, ... }:
    {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          example = false;
          description = ''
            If set to false, the user account will not have any Marchyo stuff.
          '';
        };

        name = mkOption {
          type = types.str;
          default = name;
          description = ''
            The name of the user account.
            Use `users.users.{name}.name` to reference it.
          '';
        };
        fullname = mkOption {
          type = types.str;
          description = "Your full name";
        };
        email = mkOption {
          type = types.str;
          description = "Your email address";
        };
      };
    };
in
{
  options.marchyo = {
    users = mkOption {
      default = { };
      type = with types; attrsOf (submodule userOpts);
      description = ''
        Marchyo user configuration.
        Defines users with associated metadata like fullname and email.
      '';
    };

    desktop = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable desktop environment (Hyprland, Wayland, fonts, etc.)";
      };

      useWofi = mkOption {
        type = types.bool;
        default = false;
        description = "Use wofi instead of vicinae as the application launcher";
      };
    };

    development = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable development tools (Docker, buildah, gh, etc.)";
      };
    };

    media = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable media applications (Spotify, MPV, etc.)";
      };
    };

    office = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable office applications (LibreOffice, Papers, etc.)";
      };
    };

    timezone = mkOption {
      type = types.str;
      default = "Europe/Zurich";
      example = "America/New_York";
      description = "System timezone";
    };

    defaultLocale = mkOption {
      type = types.str;
      default = "en_US.UTF-8";
      example = "de_DE.UTF-8";
      description = "System default locale";
    };

    theme = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable nix-colors theming system";
      };

      variant = mkOption {
        type = types.enum [
          "light"
          "dark"
        ];
        default = "dark";
        example = "light";
        description = ''
          Theme variant preference (light or dark).
          Used to select default color scheme when scheme is null:
          - "dark" defaults to modus-vivendi-tinted
          - "light" defaults to modus-operandi-tinted
        '';
      };

      scheme = mkOption {
        type = types.nullOr (types.either types.str types.attrs);
        default = null;
        example = "dracula";
        description = ''
          Color scheme to use. Can be:
          - A scheme name from nix-colors (e.g., "dracula", "gruvbox-dark-medium")
          - A custom color scheme name (e.g., "modus-vivendi-tinted", "modus-operandi-tinted")
          - A custom attribute set defining base00-base0F colors
          - null to use default scheme based on variant
        '';
      };
    };

    keyboard = {
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

    inputMethod = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          REMOVED: This option has been removed in favor of marchyo.keyboard.layouts.

          Please migrate your configuration:

          OLD:
            marchyo.inputMethod.enable = true;
            marchyo.inputMethod.enableCJK = true;
            marchyo.keyboard.layouts = ["us" "fi"];

          NEW:
            marchyo.keyboard.layouts = [
              "us"
              "fi"
              { layout = "cn"; ime = "pinyin"; }  # For Chinese input
              # { layout = "jp"; ime = "mozc"; }  # For Japanese input
              # { layout = "kr"; ime = "hangul"; }  # For Korean input
            ];

          See CLAUDE.md for complete documentation.
        '';
      };

      triggerKey = mkOption {
        type = types.listOf types.str;
        default = [
          "Super+I"
          "Zenkaku_Hankaku"
          "Hangul"
        ];
        example = [
          "Alt+grave"
          "Super+I"
        ];
        description = ''
          DEPRECATED: Use marchyo.keyboard.imeTriggerKey instead.

          This option is kept for compatibility but will be removed in a future release.
        '';
      };

      enableCJK = mkOption {
        type = types.bool;
        default = true;
        description = ''
          DEPRECATED: Add CJK layouts to marchyo.keyboard.layouts instead.

          Example:
            marchyo.keyboard.layouts = [
              "us"
              { layout = "cn"; ime = "pinyin"; }  # Chinese
              { layout = "jp"; ime = "mozc"; }    # Japanese
              { layout = "kr"; ime = "hangul"; }  # Korean
            ];

          This option is kept for compatibility but will be removed in a future release.
        '';
      };
    };
  };
}
