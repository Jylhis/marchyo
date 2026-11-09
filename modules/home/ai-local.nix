{
  lib,
  osConfig ? { },
  ...
}:
let
  marchyo = osConfig.marchyo or { };
  cfg = marchyo.ai.local or { };
  enabled =
    (cfg.enable or false)
    && (marchyo.development.enable or false)
    && (marchyo.defaults.aiAgent or null) == "opencode";

  connectHost =
    if
      builtins.elem cfg.host [
        "0.0.0.0"
        "::"
      ]
    then
      "127.0.0.1"
    else if lib.hasInfix ":" cfg.host then
      "[${cfg.host}]"
    else
      cfg.host;
in
{
  config = lib.mkIf enabled {
    programs.opencode = {
      enable = lib.mkDefault true;
      package = lib.mkDefault null;
      settings.provider.ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "Ollama (local)";
        options.baseURL = "http://${connectHost}:${toString cfg.port}/v1";
        models = lib.genAttrs cfg.models (name: {
          inherit name;
        });
      };
    };
  };
}
