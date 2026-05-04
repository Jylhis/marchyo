{
  pkgs,
  osConfig ? { },
  ...
}:
let
  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  isDark = themeVariant == "dark";
  designSrc = "${pkgs.jylhis-themes}/share/jylhis/bat";
in
{
  config = {
    programs.bat = {
      enable = true;

      themes = {
        jylhis-roast = {
          src = "${designSrc}/jylhis-roast.tmTheme";
        };
        jylhis-paper = {
          src = "${designSrc}/jylhis-paper.tmTheme";
        };
      };

      config.theme = if isDark then "jylhis-roast" else "jylhis-paper";
    };
  };
}
