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
        Selects the Jylhis Design System palette from the survey theme
        (themes/survey.json):
        - "dark" uses Jylhis Field (survey dark)
        - "light" uses Jylhis Sheet (survey light)
        Override with `marchyo.theme.scheme` to use a base16-schemes YAML instead.
      '';
    };

    themes = mkOption {
      type = types.listOf types.str;
      default = [
        "jylhis-dark"
        "jylhis-light"
      ];
      example = [
        "jylhis-dark"
        "jylhis-light"
        "nord"
        "gruvbox-dark-hard"
      ];
      description = ''
        Themes available for runtime switching (`marchyo theme set/next`).
        Each listed theme's desktop assets are pre-built into the system
        closure so switching is an instant symlink swap. `jylhis-dark` and
        `jylhis-light` are the Jylhis Design System variants; any other
        name must match a `.yaml` file under the `base16-schemes` package
        (e.g. "nord", "gruvbox-dark-hard"). This does not change the
        build-time default — see `variant`/`scheme` for that.
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

    fontScale = mkOption {
      type = types.numbers.between 0.5 4.0;
      default = 1.25;
      example = 1.0;
      description = ''
        Global font-size multiplier applied system-wide. Scales every text
        surface (Stylix applications/terminal/desktop/popups, the terminal,
        waybar, notifications, the lock screen, the launcher, GTK apps and the
        TTY console) from a single number. 1.0 restores the historical sizes;
        values above 1.0 make everything larger for HiDPI/accessibility.
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
