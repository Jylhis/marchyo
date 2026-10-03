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
      type = types.listOf (
        types.either types.str (
          types.submodule {
            options = {
              name = mkOption {
                type = types.str;
                description = "Theme name (shown by `marchyo theme list`, used by `set`).";
              };
              variant = mkOption {
                type = types.enum [
                  "dark"
                  "light"
                ];
                description = "Polarity, so the wallpaper and light/dark surfaces track it.";
              };
              slots = mkOption {
                type = types.attrsOf types.str;
                example = lib.literalExpression ''{ base00 = "#1d2021"; base05 = "#d4be98"; /* … base0F */ }'';
                description = ''
                  The 16 base16 colour slots `base00`..`base0F` as `#rrggbb`
                  strings. This is the universal palette contract: an omarchy
                  `colors.toml` or a matugen-generated palette both map onto it,
                  and every runtime surface (the shell's colors.json, ghostty,
                  Hyprland borders, mako, waybar, GTK) is derived from these.
                '';
              };
              wallpaper = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = ''
                  Wallpaper for this theme. Defaults to the Jylhis grid of
                  matching polarity when unset.
                '';
              };
            };
          }
        )
      );
      default = [
        "jylhis-dark"
        "jylhis-light"
      ];
      example = lib.literalExpression ''
        [
          "jylhis-dark"
          "jylhis-light"
          "nord"
          { name = "custom"; variant = "dark"; slots = { base00 = "#101010"; /* … */ }; }
        ]
      '';
      description = ''
        Themes available for runtime switching (`marchyo theme set/next`).
        Each listed theme's desktop assets are pre-built into the system
        closure so switching is an instant symlink swap. Entries may be:

        - `"jylhis-dark"` / `"jylhis-light"` — the Jylhis Design System variants;
        - any other string — the name of a `.yaml` in the tinted-schemes
          catalog's `base16/` directory (e.g. `"nord"`, `"gruvbox-dark-hard"`);
        - an inline base16 theme `{ name; variant; slots; wallpaper?; }` — the
          catalog machinery, so an arbitrary palette (an omarchy theme, a
          matugen result, your own) can be added without shipping it upstream.

        This does not change the build-time default — see `variant`/`scheme`.
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

    # Shell appearance scale axes, independent of the palette. Affect only the
    # Quickshell shell (marchyo.shell); neutral defaults reproduce the strip-bar
    # look. The style axes below (floatingBar, surfaceAlpha) are Caelestia-
    # inspired and deliberately non-neutral by default.
    appearance = {
      floatingBar = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Float the bar as a detached rounded pill with gaps to the screen
          edges, instead of the full-width strip. Also lifts panels, toasts,
          OSD, launcher, and tooltips off the bar's geometry and rounds them.
        '';
      };

      surfaceAlpha = mkOption {
        type = types.numbers.between 0.3 1.0;
        default = 0.85;
        description = ''
          Opacity of shell surfaces (bar, panels, toasts, OSD). Below 1 the
          home Hyprland config enables its blur effect and registers blur
          layer rules for the shell's layer-shell namespaces, giving a glass
          look; 1.0 restores fully opaque surfaces and keeps blur off.
        '';
      };

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
