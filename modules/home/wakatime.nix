# Per-user WakaTime configuration.
#
# When the user has a wakatimeApiKey set and tracking.editor is enabled,
# this module writes ~/.wakatime.cfg pointing at the local wakapi instance
# and exports WAKATIME_API_KEY into the session environment.
{
  osConfig,
  config,
  lib,
  ...
}:
let
  trackingCfg = osConfig.marchyo.tracking or { };
  editorEnabled = (trackingCfg.enable or false) && (trackingCfg.editor.enable or false);
  editorPort = trackingCfg.editor.port or 3000;

  userConfig = osConfig.marchyo.users."${config.home.username}" or { };
  apiKey = userConfig.wakatimeApiKey or null;

  enabled = editorEnabled && apiKey != null;
in
{
  config = lib.mkIf enabled {
    home.file.".wakatime.cfg".text = ''
      [settings]
      api_url = http://127.0.0.1:${toString editorPort}/api
      api_key = ${apiKey}
    '';

    home.sessionVariables = {
      WAKATIME_API_KEY = apiKey;
    };
  };
}
