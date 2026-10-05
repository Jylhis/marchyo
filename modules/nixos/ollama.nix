# Local LLM server: services.ollama with the inference backend picked from the
# GPU vendors, plus OLLAMA_HOST in every session so ollama clients (CLI,
# editor plugins) reach the local server.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.ai.local;
  inherit (config.marchyo.graphics) vendors;
  has = v: lib.elem v vendors;

  acceleration =
    if cfg.acceleration != null then
      cfg.acceleration
    else if has "nvidia" then
      "cuda"
    else if has "amd" then
      "rocm"
    else if has "intel" then
      "vulkan"
    else
      "cpu";

  ollamaCfg = config.services.ollama;
in
{
  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = lib.mkDefault pkgs."ollama-${acceleration}";
      loadModels = cfg.models;
    };

    environment.sessionVariables.OLLAMA_HOST = lib.mkDefault "http://${ollamaCfg.host}:${toString ollamaCfg.port}";
  };
}
