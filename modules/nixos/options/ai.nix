# marchyo.ai.* — BYOK (bring-your-own-key) AI tooling and desktop integration.
#
# Declaration-only (auto-discovered). Keep this file platform-neutral with no
# Linux-only package references: modules/darwin/default.nix imports
# ../nixos/options, so every option here is evaluated on darwin too. All package
# wiring lives in the impl modules (modules/nixos/ai.nix, modules/home/*).
{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.marchyo.ai = {
    enable = mkEnableOption "BYOK AI tooling and desktop integration";

    provider = mkOption {
      type = types.enum [ "openrouter" ];
      default = "openrouter";
      description = ''
        AI service provider. Only "openrouter" is supported for now; the enum
        is reserved so more providers (and local inference) can be added later.
      '';
    };

    openrouter = {
      apiKeyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/openrouter-api-key";
        description = ''
          Runtime path to a file containing the OpenRouter API key. The key is
          read at shell startup and exported as OPENROUTER_API_KEY, so it never
          enters the Nix store. Typically this points at a sops-nix secret path
          (e.g. config.sops.secrets."openrouter-api-key".path). Required when
          marchyo.ai.enable is true.
        '';
      };

      baseUrl = mkOption {
        type = types.str;
        default = "https://openrouter.ai/api/v1";
        description = "OpenRouter OpenAI-compatible API base URL.";
      };

      defaultModel = mkOption {
        type = types.str;
        default = "anthropic/claude-sonnet-4";
        example = "openai/gpt-4o";
        description = ''
          Default model slug used by the AI clients (aichat, aider, gptel).
          Any OpenRouter model slug is valid.
        '';
      };
    };

    tooling.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install the AI client CLIs (aichat, aider, opencode) for the user and
        wire them to the configured provider. On by default when marchyo.ai is
        enabled; set false to enable AI options without installing the clients.
      '';
    };

    local.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable a local inference engine. NOT YET IMPLEMENTED — declared so the
        option is stable. Enabling it currently fails an assertion. Use the
        OpenRouter provider instead (see marchyo.ai.openrouter).
      '';
    };
  };
}
