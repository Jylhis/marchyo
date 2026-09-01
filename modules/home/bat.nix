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

      # Upstream .tmTheme file names track design v2.0.0's survey theme
      # (Field = survey dark, Sheet = survey light); the local bat theme names
      # stay jylhis-{field,sheet} (referenced by delta in modules/home/git.nix).
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
