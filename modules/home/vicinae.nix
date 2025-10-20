{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib) mkIf;
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

  # Generate Vicinae theme TOML content
  generateTheme =
    colors: variant: schemeName:
    let
      themeName = "Marchyo ${if variant == "light" then "Light" else "Dark"} (${
        lib.toUpper (lib.substring 0 1 schemeName)
      }${lib.substring 1 (-1) schemeName})";
    in
    ''
      [meta]
      version = 1
      name = "${themeName}"
      description = "Generated from ${schemeName} colorscheme"
      variant = "${variant}"

      [colors]
      background = "${hex colors.base00}"
      foreground = "${hex colors.base05}"
      secondary_background = "${hex colors.base01}"
      border = "${hex colors.base03}"
      accent = "${hex colors.base0D}"

      [colors.accent_palette]
      blue = "${hex colors.base0D}"
      green = "${hex colors.base0B}"
      magenta = "${hex colors.base0E}"
      orange = "${hex colors.base09}"
      purple = "${hex colors.base0E}"
      red = "${hex colors.base08}"
      yellow = "${hex colors.base0A}"
      cyan = "${hex colors.base0C}"

      [colors.list_selected_item]
      background = "${hex colors.base02}"
      secondary_background = "${hex colors.base03}"
    '';

  themeFileName = "marchyo-${schemeName}.toml";
  themeContent = if colors != null then generateTheme colors variant schemeName else "";
in
{
  # Enable vicinae by default when theming is enabled, unless wofi is explicitly requested
  config = mkIf (cfg != null && cfg.enable && colors != null && !useWofi) {
    services.vicinae = {
      enable = true;
      autoStart = true;
      settings = {
        # Configure window appearance
        window = {
          opacity = 0.95;
          rounding = 0;
        };

        # Use generated theme
        theme = {
          name = "marchyo-${schemeName}";
        };

        # Font configuration
        font = {
          size = 18;
        };
      };
    };

    # Write the generated theme file
    home.file.".local/share/vicinae/themes/${themeFileName}" = {
      text = themeContent;
    };
  };
}
