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
    };
  };
}
