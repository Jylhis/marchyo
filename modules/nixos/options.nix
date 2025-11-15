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
    inputMethod = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable fcitx5 input method framework for CJK input.

          Note: Basic keyboard layout switching (US, Finnish, etc.) is handled
          by XKB configuration (see marchyo.keyboard options).
          fcitx5 is used only for complex input methods like Chinese Pinyin,
          Japanese Mozc, and Korean Hangul.
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
          List of key combinations to activate fcitx5 CJK input methods.
          Default includes Super+I, Zenkaku_Hankaku (Japanese), and Hangul (Korean) keys.

          Note: This is different from keyboard layout switching (Super+Space).
          These keys activate CJK input methods when you need to type Chinese/Japanese/Korean.
        '';
      };

      enableCJK = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Enable CJK (Chinese, Japanese, Korean) input methods.

          When enabled, adds:
          - Pinyin for Chinese input
          - Mozc for Japanese input
          - Hangul for Korean input

          When disabled, only Unicode character picker is available via fcitx5.
        '';
      };
    };
  };
}
