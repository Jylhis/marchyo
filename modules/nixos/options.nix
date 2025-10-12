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
  };
}
