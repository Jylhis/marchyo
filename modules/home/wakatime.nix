# Per-user WakaTime configuration.
#
# When the user has a WakaTime key configured and tracking.editor is enabled,
# this module writes ~/.wakatime.cfg pointing at the local wakapi instance.
#
# Two key sources are supported:
#   - wakatimeApiKeyFile (preferred): the key is read from a user-readable file
#     at activation time and templated into ~/.wakatime.cfg, so it never enters
#     the world-readable Nix store.
#   - wakatimeApiKey (legacy): the key is interpolated directly and therefore
#     lands in the store. Kept for back-compat; emits a warning.
{
  osConfig ? { },
  config,
  lib,
  ...
}:
let
  marchyoCfg = osConfig.marchyo or { };
  trackingCfg = marchyoCfg.tracking or { };
  editorCfg = trackingCfg.editor or { };
  editorEnabled = (trackingCfg.enable or false) && (editorCfg.enable or false);
  editorPort = editorCfg.port or 3000;

  userConfig = (marchyoCfg.users or { })."${config.home.username}" or { };
  apiKeyFile = userConfig.wakatimeApiKeyFile or null;
  apiKey = userConfig.wakatimeApiKey or null;

  apiUrl = "http://127.0.0.1:${toString editorPort}/api";

  enabled = editorEnabled && (apiKeyFile != null || apiKey != null);
in
{
  config = lib.mkIf enabled (
    lib.mkMerge [
      # Warn (once) when the legacy in-store key is used without a file override.
      (lib.mkIf (apiKeyFile == null && apiKey != null) {
        warnings = [
          ''
            marchyo.users.${config.home.username}.wakatimeApiKey writes the
            WakaTime key into the world-readable Nix store. Set
            wakatimeApiKeyFile instead to keep it out of the store.
          ''
        ];

        home.file.".wakatime.cfg".text = ''
          [settings]
          api_url = ${apiUrl}
          api_key = ${apiKey}
        '';
      })

      # Preferred path: template the key in from a file at activation time.
      (lib.mkIf (apiKeyFile != null) {
        home.activation.marchyoWakatimeCfg = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          key=""
          if [ -r "${toString apiKeyFile}" ]; then
            key=$(cat "${toString apiKeyFile}")
          else
            echo "marchyo: wakatimeApiKeyFile ${toString apiKeyFile} not readable; writing ~/.wakatime.cfg without a key" >&2
          fi
          run install -m600 /dev/null "$HOME/.wakatime.cfg"
          {
            echo "[settings]"
            echo "api_url = ${apiUrl}"
            echo "api_key = $key"
          } > "$HOME/.wakatime.cfg"
        '';
      })
    ]
  );
}
