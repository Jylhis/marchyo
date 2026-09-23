{
  pkgs,
  osConfig ? { },
  ...
}:
let
  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  isDark = themeVariant == "dark";
  # Design system 3.0.0 generates the tmThemes in-derivation; the built
  # jylhis-themes package is their only source. The internal theme names are
  # "Jylhis Dark" / "Jylhis Light".
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
