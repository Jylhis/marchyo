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
  };
}
