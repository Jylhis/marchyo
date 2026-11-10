{
  pkgs,
  osConfig,
  ...
}:
let
  themeVariant = osConfig.marchyo.theme.variant;
  isDark = themeVariant == "dark";
  # tmThemes come only from the built jylhis-themes package (vendored design system).
  designThemes = "${pkgs.jylhis-themes}/share/jylhis/bat";
in
{
  config = {
    programs.bat = {
      enable = true;

      themes = {
        jylhis-dark.src = "${designThemes}/jylhis-dark.tmTheme";
        jylhis-light.src = "${designThemes}/jylhis-light.tmTheme";
      };

      config.theme = if isDark then "jylhis-dark" else "jylhis-light";
    };
  };
}
