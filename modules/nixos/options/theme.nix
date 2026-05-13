{ lib, ... }:
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
        Used to select default color scheme:
        - "dark" defaults to nord
        - "light" defaults to nord-light
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
  };
}
