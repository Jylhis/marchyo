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
        Selects the Jylhis Design System palette derived from themes/jylhis.json:
        - "dark" uses Jylhis Dark (the "Negative" mode)
        - "light" uses Jylhis Light (the "Print" mode)
        Override with `marchyo.theme.scheme` to use a scheme from the
        tinted-schemes catalog instead.
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
        name must match a `.yaml` file in the tinted-schemes catalog's
        `base16/` directory (e.g. "nord", "gruvbox-dark-hard"). This does not change the
        build-time default — see `variant`/`scheme` for that.
      '';
    };

    scheme = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "nord";
      description = ''
        Override the base16 color scheme. When set, takes precedence over the
        Jylhis palette derived from `variant`. Must match a `.yaml` file in
        the tinted-schemes catalog's `base16/` directory (e.g. "nord",
        "nord-light", "gruvbox-dark-medium"). When null, the Jylhis palette
        is used.
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

    # Shell appearance scale axes, independent of the palette (Caelestia's
    # split: scale multipliers over the base design tokens). These affect only
    # the Quickshell shell (marchyo.shell); the palette stays generated from the
    # Jylhis design system. Neutral defaults reproduce the current look.
    appearance = {
      cornerRadiusScale = mkOption {
        type = types.numbers.between 0.0 4.0;
        default = 1.0;
        example = 0.0;
        description = ''
          Multiplier on the shell's corner-radius tokens (panels, OSD). 0
          squares every corner; larger values round them more. Independent of
          the palette and of fontScale.
        '';
      };

      uiScale = mkOption {
        type = types.numbers.between 0.5 4.0;
        default = 1.0;
        example = 1.2;
        description = ''
          Multiplier on the shell's geometry (bar height, spacing, padding,
          panel/OSD/notification sizes) on top of fontScale, without changing
          font sizes — a size axis separate from text scale.
        '';
      };

      animationSpeed = mkOption {
        type = types.numbers.between 0.1 10.0;
        default = 1.0;
        example = 2.0;
        description = ''
          Shell animation speed multiplier. Higher is faster (durations shrink);
          the shell exposes the resulting duration as Style.animationDuration.
        '';
      };

      highContrast = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Emphasise shell separators (thicker panel/notification borders) for a
          higher-contrast, more legible chrome. Exposed to QML as
          Style.highContrast / Style.borderWidth.
        '';
      };
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
