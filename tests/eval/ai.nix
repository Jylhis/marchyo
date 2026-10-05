# Local AI (marchyo.ai.local): services.ollama wiring, the vendor-to-backend
# package mapping, model pre-pull, and the OLLAMA_HOST session endpoint.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  ...
}:
let
  inherit (helpers) testNixOSCheck minimalConfig;

  withLocalAi =
    extra:
    lib.recursiveUpdate minimalConfig (lib.recursiveUpdate { marchyo.ai.local.enable = true; } extra);

  # services.ollama.package is the evaluated host's own pkgs.ollama-<backend>.
  # Evaluates directly (not via testNixOSCheck) to reach the host's `pkgs`.
  testBackend =
    name: backend: config:
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withLocalAi config)
        ];
      };
      ollama = eval.config.services.ollama;
    in
    pkgs.writeText "eval-${name}" (
      if ollama.enable && ollama.package.drvPath == eval.pkgs."ollama-${backend}".drvPath then
        "pass"
      else
        throw "FAIL: ${name}: services.ollama.package is not pkgs.ollama-${backend}"
    );
in
{
  eval-ai-local-off-by-default = testNixOSCheck "ai-local-off-by-default" (
    cfg:
    !cfg.marchyo.ai.local.enable
    && !cfg.services.ollama.enable
    && !(cfg.environment.sessionVariables ? OLLAMA_HOST)
  ) minimalConfig;

  eval-ai-local-enabled = testNixOSCheck "ai-local-enabled" (
    cfg:
    cfg.services.ollama.enable
    && cfg.services.ollama.loadModels == [ ]
    && cfg.environment.sessionVariables.OLLAMA_HOST == "http://127.0.0.1:11434"
  ) (withLocalAi { });

  eval-ai-local-no-vendor-cpu = testBackend "ai-local-no-vendor-cpu" "cpu" { };

  eval-ai-local-nvidia-cuda = testBackend "ai-local-nvidia-cuda" "cuda" {
    marchyo.graphics.vendors = [ "nvidia" ];
  };

  eval-ai-local-amd-rocm = testBackend "ai-local-amd-rocm" "rocm" {
    marchyo.graphics.vendors = [ "amd" ];
  };

  eval-ai-local-intel-vulkan = testBackend "ai-local-intel-vulkan" "vulkan" {
    marchyo.graphics.vendors = [ "intel" ];
  };

  # Hybrid laptops (iGPU + NVIDIA) run inference on the NVIDIA dGPU.
  eval-ai-local-hybrid-cuda = testBackend "ai-local-hybrid-cuda" "cuda" {
    marchyo.graphics.vendors = [
      "intel"
      "nvidia"
    ];
  };

  # An explicit acceleration overrides the vendor-derived backend.
  eval-ai-local-acceleration-override = testBackend "ai-local-acceleration-override" "vulkan" {
    marchyo.graphics.vendors = [ "nvidia" ];
    marchyo.ai.local.acceleration = "vulkan";
  };

  # Models are pre-pulled through services.ollama.loadModels, and a custom
  # listen port flows into OLLAMA_HOST.
  eval-ai-local-models-and-endpoint =
    testNixOSCheck "ai-local-models-and-endpoint"
      (
        cfg:
        cfg.services.ollama.loadModels == [ "llama3.2:3b" ]
        && cfg.systemd.services ? ollama-model-loader
        && cfg.environment.sessionVariables.OLLAMA_HOST == "http://127.0.0.1:11500"
      )
      (withLocalAi {
        marchyo.ai.local.models = [ "llama3.2:3b" ];
        services.ollama.port = 11500;
      });
}
