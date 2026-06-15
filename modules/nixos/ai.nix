# marchyo.ai — BYOK AI integration (NixOS layer).
#
# The user-facing wiring (client install, key export, editor integration) lives
# in the Home Manager modules (modules/home/ai-tooling.nix, ai-context.nix,
# ai-skills.nix, ai-mcp.nix), which read osConfig.marchyo.ai. This module only
# carries the system-level
# guardrails: it validates configuration and refuses the not-yet-implemented
# local-inference path.
{ config, lib, ... }:
let
  cfg = config.marchyo.ai;
in
{
  # AI agents (claude-code, …) come from llm-agents.nix's pinned set and are
  # served prebuilt from the Numtide cache. That substituter + key are already
  # configured unconditionally for every marchyo system in nix-settings.nix, so
  # this module only carries the configuration guardrails.
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.local.enable;
        message = ''
          marchyo.ai.local.enable: local inference is not yet implemented.
          Use the OpenRouter provider instead (set marchyo.ai.openrouter.apiKeyFile).
        '';
      }
      {
        assertion = cfg.openrouter.apiKeyFile != null;
        message = ''
          marchyo.ai.enable requires marchyo.ai.openrouter.apiKeyFile to be set.
          Point it at a file containing your OpenRouter API key (typically a
          sops-nix secret path, e.g. config.sops.secrets."openrouter-api-key".path).
        '';
      }
    ];
  };
}
