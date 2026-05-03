# Mako notification daemon — Jylhis Design System (Roast)
# Accent left-border, monospace meta, dark roast bg.
{
  lib,
  osConfig ? { },
  ...
}:
let
  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  isDark = themeVariant == "dark";
in
{
  config = {
    services.mako = {
      enable = true;

      settings = lib.mkForce {
        font = "JetBrainsMono Nerd Font 11";
        width = 380;
        height = 120;
        margin = "12";
        padding = "14,16";
        border-size = 1;
        border-radius = 4;
        max-icon-size = 32;
        layer = "overlay";
        anchor = "top-right";
        default-timeout = 6000;
        ignore-timeout = false;
        max-visible = 5;
        sort = "-time";
        group-by = "app-name";
        actions = true;
        markup = true;

        background-color = if isDark then "#2a2520" else "#fefdfb";
        text-color = if isDark then "#e8e0d4" else "#2c2825";
        border-color = if isDark then "#5a5248" else "#d5cec4";
        progress-color = if isDark then "over #e89b5e" else "over #9a5a2a";

        format = "<b>%s</b>\\n%b";

        "urgency=low" = {
          border-color = if isDark then "#6b6157" else "#c4baa8";
        };
        "urgency=critical" = {
          background-color = if isDark then "#3a1f1c" else "#fff0f0";
          text-color = if isDark then "#ff7f7f" else "#a60000";
          border-color = if isDark then "#ff5f59" else "#a60000";
          default-timeout = 0;
        };
      };
    };
  };
}
