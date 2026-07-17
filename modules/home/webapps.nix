{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);
  cfg = (osConfig.marchyo or { }).webapps or { };
  enabled = desktopEnabled && (cfg.enable or false);

  apps = cfg.apps or [ ];

  # Resolve the chromium-family command used for --app mode. Prefer an explicit
  # marchyo.webapps.browser, else follow marchyo.defaults.browser when it is
  # chromium-based, else fall back to chromium (and pull it into the profile).
  chromiumFamily = {
    brave = "brave";
    google-chrome = "google-chrome";
    chromium = "chromium";
  };
  explicit = cfg.browser or null;
  defaultBrowser = ((osConfig.marchyo or { }).defaults or { }).browser or null;
  resolved =
    if explicit != null then
      chromiumFamily.${explicit}
    else if defaultBrowser != null && chromiumFamily ? ${defaultBrowser} then
      chromiumFamily.${defaultBrowser}
    else
      null;
  browserCmd = if resolved != null then resolved else "chromium";
  needsChromium = resolved == null;

  slug = name: lib.toLower (builtins.replaceStrings [ " " "/" ] [ "-" "-" ] name);

  appExec = app: "${browserCmd} --app=${app.url}";

  mkEntry = app: {
    name = "marchyo-webapp-${slug app.name}";
    value = {
      inherit (app) name;
      genericName = "Web App";
      exec = appExec app;
      icon = if app.icon != null then app.icon else "applications-internet";
      terminal = false;
      categories = [ "Network" ];
    };
  };

  # Hyprland launch binds for apps that declare a key (omarchy-style). Reuses
  # the same resolved browser command as the .desktop entries.
  keyedApps = builtins.filter (app: (app.key or null) != null) apps;
  mkBind = app: "${app.modifiers}, ${app.key}, ${app.name}, exec, ${appExec app}";
in
{
  config = lib.mkIf enabled {
    xdg.desktopEntries = builtins.listToAttrs (map mkEntry apps);
    home.packages = lib.optional needsChromium pkgs.chromium;

    # Merges with the bindd lists from hyprland.nix / screenshot.nix (home-manager
    # concatenates the list); order is irrelevant to Hyprland.
    wayland.windowManager.hyprland.settings.bindd = map mkBind keyedApps;
  };
}
