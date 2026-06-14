# marchyo.ai — BYOK AI integration (NixOS layer).
#
# The user-facing wiring (client install, key export, editor integration) lives
# in the Home Manager modules (modules/home/ai-tooling.nix, modules/home/emacs.nix),
# which can read osConfig.marchyo.ai. This module only carries the system-level
# guardrails: it validates configuration and refuses the not-yet-implemented
# local-inference path.
{ config, lib, ... }:
let
  cfg = config.marchyo.ai;
in
{
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
