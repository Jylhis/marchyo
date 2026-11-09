{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.ai.local;
  inherit (config.marchyo.graphics) vendors;
  inherit (config.marchyo.graphics.amd) rocm;

  auto =
    if builtins.elem "nvidia" vendors then
      "cuda"
    else if builtins.elem "amd" vendors && rocm.enable then
      "rocm"
    else
      null;

  packages = {
    cuda = pkgs.ollama-cuda;
    rocm = pkgs.ollama-rocm;
    cpu = pkgs.ollama-cpu;
  };

  acceleration = if cfg.acceleration != null then cfg.acceleration else auto;
in
{
  config = lib.mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = if acceleration == null then pkgs.ollama else packages.${acceleration};
      inherit (cfg) host port;
      loadModels = cfg.models;
      rocmOverrideGfx = lib.mkIf (acceleration == "rocm") rocm.hsaOverrideGfxVersion;
    };
  };
}
