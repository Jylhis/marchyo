{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  hlua = import ../../lib/hyprland-lua.nix { inherit lib; };
  desktopEnabled = pkgs.stdenv.hostPlatform.isLinux && osConfig.marchyo.desktop.enable;
  cfg = osConfig.marchyo.webapps;
  enabled = desktopEnabled && cfg.enable;

  presetOn = name: cfg.presets.${name}.enable;
  webappPresets = import ../../lib/webapp-presets.nix;
  notionNative =
    presetOn "notion" && pkgs.config.allowUnfree && pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  emailChoice = osConfig.marchyo.defaults.email;
  emailAppName = {
    gmail = "Gmail";
    outlook = "Outlook";
  };
  emailApp = lib.optionals (emailChoice != null && emailAppName ? ${emailChoice}) (
    lib.filter (a: a.name == emailAppName.${emailChoice}) (webappPresets.google ++ webappPresets.m365)
  );
  presetApps =
    lib.optionals (presetOn "m365") webappPresets.m365
    ++ lib.optionals (presetOn "google") webappPresets.google
    ++ lib.optional (presetOn "notion" && !notionNative) webappPresets.notion
    ++ emailApp;

  # Presets go last: listToAttrs keeps the first entry per name, so an app the
  # user already lists (the default Gmail, say) wins over the preset copy.
  apps = cfg.apps ++ cfg.extraApps ++ presetApps;

  webappBrowser = import ../../lib/webapp-browser.nix { inherit osConfig; };
  browserCmd = webappBrowser.command;
  inherit (webappBrowser) needsChromium;

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

  # Launch binds (lib/keybinds.nix) for apps that declare a key. Reuses the
  # same resolved browser command as the .desktop entries.
  keyedApps = builtins.filter (app: (app.key or null) != null) apps;
  # `modifiers` keeps its "SUPER SHIFT" form in the option; luaKeys turns it
  # into the "SUPER + SHIFT + A" the Lua renderer wants.
  mkBind = app: {
    combo = hlua.luaKeys app.modifiers app.key;
    inherit (app) name;
    command = appExec app;
  };
in
{
  config = lib.mkIf enabled {
    xdg.desktopEntries = builtins.listToAttrs (map mkEntry apps);
    home.packages =
      lib.optional needsChromium pkgs.chromium ++ lib.optional notionNative pkgs.notion-app-enhanced;

    marchyo.keybinds.webapps = map mkBind keyedApps;
  };
}
