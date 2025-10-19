{
  lib,
  config,
  osConfig,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = if osConfig ? marchyo then osConfig.marchyo.theme else null;
  colors = if config ? colorScheme then config.colorScheme.palette else null;
  hex = color: "#${color}";
  variant = if config ? colorScheme then config.colorScheme.variant else "dark";
in
{
  config = mkIf (cfg != null && cfg.enable && colors != null) {
    # Note: Obsidian theming via Home Manager is limited.
    # The configuration below sets up CSS snippets, but you'll need to:
    # 1. Enable the CSS snippet in Obsidian settings: Settings > Appearance > CSS snippets
    # 2. Consider installing a Base16-compatible theme from the community themes

    programs.obsidian = {
      enable = true;
      settings = {
        appearance = {
          theme = variant;
        };
        cssSnippets = [
          {
            name = "marchyo-base16";
            text = ''
              .theme-${variant} {
                --color-base-00: ${hex colors.base00};
                --color-base-05: ${hex colors.base05};
                --color-base-10: ${hex colors.base00};
                --color-base-20: ${hex colors.base01};
                --color-base-25: ${hex colors.base02};
                --color-base-30: ${hex colors.base03};
                --color-base-35: ${hex colors.base04};
                --color-base-40: ${hex colors.base04};
                --color-base-50: ${hex colors.base05};
                --color-base-60: ${hex colors.base06};
                --color-base-70: ${hex colors.base07};
                --color-base-100: ${hex colors.base07};

                --color-accent: ${hex colors.base0D};
                --color-accent-hsl: ${hex colors.base0D};

                --text-normal: ${hex colors.base05};
                --text-muted: ${hex colors.base04};
                --text-faint: ${hex colors.base03};
                --text-error: ${hex colors.base08};
                --text-accent: ${hex colors.base0D};
                --text-accent-hover: ${hex colors.base0C};
                --text-selection: ${hex colors.base02};

                --background-primary: ${hex colors.base00};
                --background-secondary: ${hex colors.base01};
                --background-modifier-border: ${hex colors.base03};
                --background-modifier-form-field: ${hex colors.base01};
                --background-modifier-success: ${hex colors.base0B};
                --background-modifier-error: ${hex colors.base08};

                --interactive-normal: ${hex colors.base01};
                --interactive-hover: ${hex colors.base02};
                --interactive-accent: ${hex colors.base0D};
                --interactive-accent-hover: ${hex colors.base0C};
              }
            '';
          }
        ];
      };
    };
  };
}
