{
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf mkMerge;
  cfg = if osConfig ? marchyo then osConfig.marchyo.theme else null;
  useWofi = if osConfig ? marchyo then osConfig.marchyo.desktop.useWofi or false else false;
  colors = if config ? colorScheme then config.colorScheme.palette else null;
  variant = if config ? colorScheme then config.colorScheme.variant else "dark";
  schemeName =
    if config ? colorScheme then
      (config.colorScheme.slug or config.colorScheme.name or "marchyo")
    else
      "marchyo";

  # Helper to format hex color with # prefix
  hex = color: "#${color}";

  # Generate Vicinae theme as Nix attribute set
  generateTheme =
    colors: variant: schemeName:
    let
      themeName = "Marchyo ${if variant == "light" then "Light" else "Dark"} (${
        lib.toUpper (lib.substring 0 1 schemeName)
      }${lib.substring 1 (-1) schemeName})";
      baseTheme = if variant == "light" then "vicinae-light" else "vicinae-dark";
    in
    {
      meta = {
        version = 1;
        name = themeName;
        description = "Generated from ${schemeName} colorscheme";
        inherit variant;
        inherits = baseTheme;
      };

      colors = {
        core = {
          accent = hex colors.base0D;
          accent_foreground = hex colors.base00;
          background = hex colors.base00;
          foreground = hex colors.base05;
          secondary_background = hex colors.base01;
          border = hex colors.base03;
        };

        main_window = {
          border = hex colors.base03;
        };

        settings_window = {
          border = hex colors.base03;
        };

        accents = {
          blue = hex colors.base0D;
          green = hex colors.base0B;
          magenta = hex colors.base0E;
          orange = hex colors.base09;
          purple = hex colors.base0E;
          red = hex colors.base08;
          yellow = hex colors.base0A;
          cyan = hex colors.base0C;
        };

        text = {
          default = hex colors.base05;
          muted = hex colors.base04;
          danger = hex colors.base08;
          success = hex colors.base0B;
          placeholder = hex colors.base04;

          selection = {
            background = hex colors.base0D;
            foreground = hex colors.base00;
          };

          links = {
            default = hex colors.base0D;
            visited = hex colors.base0E;
          };
        };

        input = {
          border = hex colors.base03;
          border_focus = hex colors.base0D;
          border_error = hex colors.base08;
        };

        button = {
          primary = {
            background = hex colors.base02;
            foreground = hex colors.base05;

            hover = {
              background = hex colors.base03;
            };

            focus = {
              outline = hex colors.base0D;
            };
          };
        };

        list = {
          item = {
            hover = {
              background = hex colors.base02;
              foreground = hex colors.base05;
            };

            selection = {
              background = hex colors.base02;
              foreground = hex colors.base05;
              secondary_background = hex colors.base03;
              secondary_foreground = hex colors.base05;
            };
          };
        };

        grid = {
          item = {
            background = hex colors.base01;

            hover = {
              outline = hex colors.base05;
            };

            selection = {
              outline = hex colors.base0D;
            };
          };
        };

        scrollbars = {
          background = hex colors.base02;
        };

        loading = {
          bar = hex colors.base0D;
          spinner = hex colors.base0D;
        };
      };
    };

  themeFileName = "marchyo-${schemeName}.toml";
  themeAttrs = if colors != null then generateTheme colors variant schemeName else null;
  tomlFormat = pkgs.formats.toml { };
in
{
  # Enable vicinae when wofi is not explicitly requested
  config = mkIf (!useWofi) {
    services.vicinae = {
      enable = true;
      settings = mkMerge [
        {
          # Configure window appearance
          window = {
            opacity = 0.95;
            rounding = 0;
          };

          # Font configuration
          font = {
            size = 18;
          };
        }
        (mkIf (cfg != null && cfg.enable && colors != null) {
          # Use generated theme
          theme = {
            name = "marchyo-${schemeName}";
          };
        })
      ];
    };

    # Write the generated theme file using pkgs.formats.toml
    home.file.".local/share/vicinae/themes/${themeFileName}" =
      mkIf (cfg != null && cfg.enable && themeAttrs != null)
        {
          source = tomlFormat.generate themeFileName themeAttrs;
        };
  };
}
