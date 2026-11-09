# marchyo.ai.local: Ollama package choice per GPU vendor and acceleration,
# option mapping, the opencode provider, and the retired alias.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) testNixOSCheck minimalConfig withTestUser;

  desc = c: c.services.ollama.package.meta.description;
  isCuda = c: lib.hasInfix "CUDA" (desc c);
  isRocm = c: lib.hasInfix "ROCm" (desc c);
  isPlain = c: !isCuda c && !isRocm c && c.services.ollama.package.drvPath == pkgs.ollama.drvPath;

  local =
    extra:
    lib.recursiveUpdate minimalConfig {
      marchyo = lib.recursiveUpdate { ai.local.enable = true; } extra;
    };

  amdRocm = {
    vendors = [ "amd" ];
    amd.rocm = {
      enable = true;
      hsaOverrideGfxVersion = "10.3.0";
    };
  };

  opencodeEval =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo = {
              development.enable = true;
              defaults.aiAgent = "opencode";
              ai.local = {
                enable = true;
                models = [ "qwen3:8b" ];
                port = 11500;
              };
            };
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };
  opencodeSettings =
    extra: (opencodeEval extra).config.home-manager.users.testuser.programs.opencode.settings;
in
{
  eval-ai-local-default-off = testNixOSCheck "ai-local-default-off" (
    c: !c.services.ollama.enable
  ) minimalConfig;

  eval-ai-local-cpu-default = testNixOSCheck "ai-local-cpu-default" (
    c:
    c.services.ollama.enable
    && isPlain c
    && c.services.ollama.host == "127.0.0.1"
    && c.services.ollama.port == 11434
  ) (local { });

  eval-ai-local-nvidia-cuda = testNixOSCheck "ai-local-nvidia-cuda" isCuda (local {
    graphics.vendors = [ "nvidia" ];
  });

  eval-ai-local-amd-rocm =
    testNixOSCheck "ai-local-amd-rocm" (c: isRocm c && c.services.ollama.rocmOverrideGfx == "10.3.0")
      (local {
        graphics = amdRocm;
      });

  eval-ai-local-amd-without-rocm = testNixOSCheck "ai-local-amd-without-rocm" isPlain (local {
    graphics.vendors = [ "amd" ];
  });

  eval-ai-local-mixed-nvidia-wins = testNixOSCheck "ai-local-mixed-nvidia-wins" isCuda (local {
    graphics = amdRocm // {
      vendors = [
        "amd"
        "nvidia"
      ];
    };
  });

  eval-ai-local-acceleration-override =
    testNixOSCheck "ai-local-acceleration-override" isRocm
      (local {
        graphics.vendors = [ "nvidia" ];
        ai.local.acceleration = "rocm";
      });

  eval-ai-local-acceleration-cpu =
    testNixOSCheck "ai-local-acceleration-cpu"
      (c: !isCuda c && c.services.ollama.package.drvPath == pkgs.ollama-cpu.drvPath)
      (local {
        graphics.vendors = [ "nvidia" ];
        ai.local.acceleration = "cpu";
      });

  eval-ai-local-options-mapped =
    testNixOSCheck "ai-local-options-mapped"
      (
        c:
        c.services.ollama.loadModels == [
          "qwen3:8b"
          "llama3.2"
        ]
        && c.services.ollama.host == "0.0.0.0"
        && c.services.ollama.port == 11500
      )
      (local {
        ai.local = {
          models = [
            "qwen3:8b"
            "llama3.2"
          ];
          host = "0.0.0.0";
          port = 11500;
        };
      });

  eval-ai-local-opencode-provider = pkgs.writeText "eval-ai-local-opencode-provider" (
    let
      p = (opencodeSettings { }).provider.ollama;
    in
    if
      p.npm == "@ai-sdk/openai-compatible"
      && p.options.baseURL == "http://127.0.0.1:11500/v1"
      && p.models ? "qwen3:8b"
    then
      "pass"
    else
      throw "FAIL: opencode ollama provider missing or wrong: ${builtins.toJSON p}"
  );

  eval-ai-local-opencode-wildcard-host = pkgs.writeText "eval-ai-local-opencode-wildcard-host" (
    let
      url = (opencodeSettings { marchyo.ai.local.host = "0.0.0.0"; }).provider.ollama.options.baseURL;
    in
    if url == "http://127.0.0.1:11500/v1" then
      "pass"
    else
      throw "FAIL: wildcard host should connect through loopback, got ${url}"
  );

  eval-ai-local-opencode-other-agent = pkgs.writeText "eval-ai-local-opencode-other-agent" (
    let
      s = opencodeSettings { marchyo.defaults.aiAgent = "codex"; };
    in
    if s ? provider then throw "FAIL: opencode provider set although aiAgent is codex" else "pass"
  );

  eval-ai-local-alias-gone = testNixOSCheck "ai-local-alias-gone" (c: c.marchyo.ai.local.enable) (
    local { }
  );
}
