{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.marchyo.ai.local = {
    enable = lib.mkEnableOption ''
      a local LLM server (Ollama) listening on localhost. The GPU backend is
      derived from `marchyo.graphics.vendors` (see `acceleration`) and the
      endpoint is exported to every session as `OLLAMA_HOST`'';

    acceleration = mkOption {
      type = types.nullOr (
        types.enum [
          "cpu"
          "vulkan"
          "rocm"
          "cuda"
        ]
      );
      default = null;
      example = "vulkan";
      description = ''
        Ollama inference backend, selecting the matching `pkgs.ollama-*`
        package. When null it is derived from `marchyo.graphics.vendors`:
        "nvidia" selects "cuda", otherwise "amd" selects "rocm", otherwise
        "intel" selects "vulkan", and no listed vendor selects "cpu".
      '';
    };

    models = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "llama3.2:3b"
        "qwen2.5-coder:7b"
      ];
      description = ''
        Ollama models pulled after the server starts (`services.ollama.loadModels`).
        The pull runs in a separate service and needs network access when it runs;
        it never blocks a rebuild.
      '';
    };
  };
}
