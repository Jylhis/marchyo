# Per-user BYOK AI client tooling.
#
# Enabled when marchyo.ai.enable && marchyo.ai.tooling.enable. Installs the AI
# client CLIs and wires them to OpenRouter. The API key is read from
# marchyo.ai.openrouter.apiKeyFile at interactive-shell startup and exported as
# OPENROUTER_API_KEY, so it never enters the Nix store (mirrors the pattern in
# modules/home/tracking/claude-code.nix). aichat, aider and opencode all consume
# that single env var.
{
  osConfig ? { },
  lib,
  pkgs,
  ...
}:
let
  aiCfg = (osConfig.marchyo or { }).ai or { };
  orCfg = aiCfg.openrouter or { };
  enabled = (aiCfg.enable or false) && (aiCfg.tooling.enable or true);

  defaultModel = orCfg.defaultModel or "anthropic/claude-sonnet-4";
  keyFile = if (orCfg.apiKeyFile or null) == null then "" else toString orCfg.apiKeyFile;

  shellInit = ''
    if [ -r "${keyFile}" ]; then
      export OPENROUTER_API_KEY="$(cat "${keyFile}")"
    fi
  '';

  fishInit = ''
    if test -r "${keyFile}"
        set -gx OPENROUTER_API_KEY (cat "${keyFile}")
    end
  '';
in
{
  config = lib.mkIf enabled {
    home.packages = [
      pkgs.aichat
      pkgs.aider-chat
      pkgs.opencode
      # claude-code speaks the Anthropic API, not OpenAI/OpenRouter — it is
      # installed for convenience but NOT wired to OpenRouter. Authenticate it
      # separately with an Anthropic key.
      pkgs.claude-code
    ];

    # OpenRouter key (secret) — exported from a file at runtime, never in store.
    programs.bash.initExtra = shellInit;
    programs.zsh.initExtra = shellInit;
    programs.fish.interactiveShellInit = fishInit;

    # Non-secret env: model selection for the clients that read it.
    home.sessionVariables = {
      AIDER_MODEL = "openrouter/${defaultModel}";
    };

    # aichat uses its built-in OpenRouter client, which reads OPENROUTER_API_KEY.
    xdg.configFile."aichat/config.yaml".text = ''
      model: openrouter:${defaultModel}
      save: true
      keybindings: emacs
    '';
  };
}
