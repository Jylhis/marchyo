{ lib, pkgs, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.theme = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Stylix theming system";
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
        Selects the Jylhis Design System palette derived from tokens.json:
        - "dark" uses Jylhis Roast
        - "light" uses Jylhis Paper
        Override with `marchyo.theme.scheme` to use a base16-schemes YAML instead.
      '';
    };

    scheme = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "nord";
      description = ''
        Override the base16 color scheme. When set, takes precedence over the
        Jylhis palette derived from `variant`. Must match a `.yaml` file under
        the `base16-schemes` package (e.g. "nord", "nord-light",
        "gruvbox-dark-medium"). When null, the Jylhis palette is used.
      '';
    };

    wallpaper = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the generated Marchyo grid wallpaper where supported.";
      };

      package = mkOption {
        type = types.package;
        default = pkgs.marchyo-wallpapers;
        defaultText = "pkgs.marchyo-wallpapers";
        description = "Package providing generated Marchyo wallpaper assets.";
      };
    };
  };
}
