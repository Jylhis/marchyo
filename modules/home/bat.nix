{
  pkgs,
  osConfig ? { },
  ...
}:
let
  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  isDark = themeVariant == "dark";
  designSrc = "${pkgs.jylhis-design-src}/platforms/bat";
in
{
  config = {
    programs.bat = {
      enable = true;

      themes = {
        jylhis-field = {
          src = "${designSrc}/jylhis-survey-dark.tmTheme";
        };
        jylhis-sheet = {
          src = "${designSrc}/jylhis-survey-light.tmTheme";
        };
      };

      config.theme = if isDark then "jylhis-field" else "jylhis-sheet";
    };
  };
}
