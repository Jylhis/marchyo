# Per-user OpenViking context/memory layer.
#
# Enabled when marchyo.ai.enable && marchyo.ai.context.enable. Installs the `ov`
# CLI and writes ~/.openviking/ov.conf pointing embeddings at OpenRouter. The API
# key is injected into ov.conf at activation from marchyo.ai.openrouter.apiKeyFile
# (never in the Nix store). All context data stays under the local workspace dir.
#
# Only the `ov` CLI is packaged (not the separate openviking-server crate), so
# context.service.enable is not wired yet (warned below).
{
  config,
  osConfig ? { },
  lib,
  pkgs,
  ...
}:
let
  ai = import ../../lib/ai.nix osConfig;
  inherit (ai) aiCfg baseUrl keyFile;
  ctx = aiCfg.context or { };
  enabled = ai.featureEnabled "context" false;

  workspace = "${config.home.homeDirectory}/${ctx.workspacePath or ".openviking/workspace"}";
  embeddingModel = ctx.embeddingModel or "openai/text-embedding-3-small";

  # ov.conf base (without the key); the key is merged in at activation via jq
  # so a key containing shell/sed metacharacters can never corrupt the file.
  ovConfBase = pkgs.writeText "ov.conf.base" (
    builtins.toJSON {
      storage.workspace = workspace;
      log = {
        level = "INFO";
        output = "stdout";
      };
      embedding.dense = [
        {
          provider = "openai";
          api_base = baseUrl;
          api_key = "";
          model = embeddingModel;
          dimension = 1536;
        }
      ];
    }
  );
in
{
  config = lib.mkIf enabled {
    home.packages = [ pkgs.openviking ];

    warnings = lib.optional (ctx.service.enable or false) ''
      marchyo.ai.context.service.enable is set, but only the `ov` CLI is packaged
      (not openviking-server). The HTTP service is not started. Run `ov` against an
      externally started server, or wait for the server package.
    '';

    home.activation.marchyoOpenVikingConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${workspace}"
      run mkdir -p "$HOME/.openviking"
      key=""
      if [ -r "${keyFile}" ]; then
        key=$(cat "${keyFile}")
      fi
      conf="$HOME/.openviking/ov.conf"
      # Inject the key via jq --arg (metacharacter-safe) under a restrictive
      # umask (no world-readable window before chmod); fail loudly rather than
      # leaving a truncated conf if jq errors.
      ( umask 077; ${pkgs.jq}/bin/jq --arg key "$key" \
        '.embedding.dense[0].api_key = $key' ${ovConfBase} > "$conf" ) \
        || { run rm -f "$conf"; exit 1; }
      run chmod 600 "$conf"
    '';
  };
}
