# Per-user BYOK AI client tooling.
#
# Enabled when marchyo.ai.enable && marchyo.ai.tooling.enable. Installs the AI
# client CLIs and wires the OpenRouter-backed one (pi) to the routing table.
# The API key is read from marchyo.ai.openrouter.apiKeyFile at interactive-shell
# startup and exported as OPENROUTER_API_KEY, so it never enters the Nix store.
#
# claude-code speaks the Anthropic API (not OpenAI/OpenRouter) and is installed
# but NOT wired to OpenRouter — authenticate it separately with an Anthropic key.
{
  osConfig ? { },
  lib,
  pkgs,
  ...
}:
let
  ai = import ../../lib/ai.nix osConfig;
  inherit (ai)
    aiCfg
    orCfg
    baseUrl
    keyFile
    ;
  routing = aiCfg.routing or { };
  tasks = routing.tasks or { };
  toolBuckets = routing.tools or { };
  enabled = ai.featureEnabled "tooling" true;

  fallbackModel = orCfg.defaultModel or "anthropic/claude-sonnet-4";

  # Resolve a tool's model from its routing bucket, else the global default.
  modelFor =
    tool:
    let
      bucket = toolBuckets.${tool} or null;
    in
    if (routing.enable or true) && bucket != null && tasks ? ${bucket} then
      tasks.${bucket}.model
    else
      fallbackModel;

  piModel = modelFor "pi";

  # Export the OpenRouter key from its file at interactive-shell startup. Needed
  # so the key never enters the Nix store yet reaches pi's provider extension.
  shellInit = ''
    if [ -r "${keyFile}" ]; then
      export OPENROUTER_API_KEY="$(cat "${keyFile}")"
    fi
  '';

  # pi extension registering OpenRouter as an OpenAI-compatible provider.
  # Mirrors the documented pi.registerProvider() API (best-effort; pi config is
  # JSON at ~/.pi/agent/settings.json, providers via a TS extension).
  piModelEntries = lib.concatStringsSep ",\n" (
    lib.mapAttrsToList (
      _: t:
      ''{ id: ${builtins.toJSON t.model}, name: ${builtins.toJSON t.model}, reasoning: true, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 8192 }''
    ) tasks
    ++ [
      ''{ id: "openrouter/auto", name: "OpenRouter Auto", reasoning: true, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 128000, maxTokens: 8192 }''
    ]
  );

  piProviderExtension = ''
    // Marchyo: register OpenRouter as an OpenAI-compatible provider for pi.
    export default function (pi) {
      pi.registerProvider("openrouter", {
        name: "OpenRouter",
        baseUrl: ${builtins.toJSON baseUrl},
        apiKey: "$OPENROUTER_API_KEY",
        api: "openai-completions",
        models: [
    ${piModelEntries}
        ],
      });
    }
  '';
in
{
  config = lib.mkIf enabled {
    home.packages = [
      pkgs.pi
      # Anthropic-native; not wired to OpenRouter. Sourced from llm-agents.nix
      # (daily-updated, Numtide-cached) rather than nixpkgs.
      pkgs.llm-agents.claude-code
    ];

    # OpenRouter key (secret) — exported from a file at runtime, never in store.
    programs.bash.initExtra = shellInit;

    # pi: JSON settings + OpenRouter provider extension.
    home.file = {
      ".pi/agent/settings.json".text = builtins.toJSON {
        defaultProvider = "openrouter";
        # pi uses a bare model id here (provider comes from defaultProvider) —
        # it must match a registered model id, which are bare slugs (no
        # "openrouter/" prefix). See pi docs/settings.md.
        defaultModel = piModel;
        defaultThinkingLevel = "medium";
      };
      ".pi/agent/extensions/marchyo-openrouter.ts".text = piProviderExtension;
    };
  };
}
