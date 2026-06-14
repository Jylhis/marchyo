# Per-user BYOK AI client tooling.
#
# Enabled when marchyo.ai.enable && marchyo.ai.tooling.enable. Installs the AI
# client CLIs and wires the OpenRouter-backed ones (aichat, pi) to the routing
# table. The API key is read from marchyo.ai.openrouter.apiKeyFile at
# interactive-shell startup and exported as OPENROUTER_API_KEY, so it never
# enters the Nix store (mirrors modules/home/tracking/claude-code.nix).
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
  aiCfg = (osConfig.marchyo or { }).ai or { };
  orCfg = aiCfg.openrouter or { };
  routing = aiCfg.routing or { };
  tasks = routing.tasks or { };
  toolBuckets = routing.tools or { };
  enabled = (aiCfg.enable or false) && (aiCfg.tooling.enable or true);

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

  aichatModel = modelFor "aichat";
  piModel = modelFor "pi";

  # All routed models (+ the aichat default), for the aichat client model list.
  aichatModels = lib.unique ([ aichatModel ] ++ lib.mapAttrsToList (_: t: t.model) tasks);
  # Double-quoted (not '''') so leading indentation is preserved verbatim.
  aichatModelsYaml = lib.concatMapStringsSep "\n" (m: "          - name: \"${m}\"") aichatModels;

  keyFile = if (orCfg.apiKeyFile or null) == null then "" else toString orCfg.apiKeyFile;
  baseUrl = orCfg.baseUrl or "https://openrouter.ai/api/v1";

  # Wrapper that loads the OpenRouter key from the file before exec'ing aichat.
  # Needed for non-shell launchers (e.g. the Hyprland Super+A bind runs the
  # command directly via Ghostty `-e`, bypassing interactive shell init).
  marchyoAichat = pkgs.writeShellApplication {
    name = "marchyo-aichat";
    runtimeInputs = [ pkgs.aichat ];
    text = ''
      if [ -r "${keyFile}" ]; then
        OPENROUTER_API_KEY="$(cat "${keyFile}")"
        export OPENROUTER_API_KEY
      fi
      exec aichat "$@"
    '';
  };

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

  # Machine-readable routing policy for the future gateway / marchyo CLI.
  routingJson = builtins.toJSON {
    inherit (routing) enable;
    tools = toolBuckets;
    tasks = lib.mapAttrs (_: t: {
      inherit (t) model fallbacks;
    }) tasks;
  };

  # An aichat role per task bucket: `aichat -r frontier "..."`.
  bucketRoleFiles = lib.mapAttrs' (
    bucket: t:
    lib.nameValuePair "aichat/roles/${bucket}.md" {
      text = ''
        ---
        model: openrouter:${t.model}
        ---
        You are an assistant configured for the "${bucket}" task profile.
      '';
    }
  ) tasks;

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
      pkgs.aichat
      marchyoAichat
      pkgs.pi
      # Anthropic-native; not wired to OpenRouter. Sourced from llm-agents.nix
      # (daily-updated, Numtide-cached) rather than nixpkgs.
      pkgs.llm-agents.claude-code
    ];

    # OpenRouter key (secret) — exported from a file at runtime, never in store.
    programs.bash.initExtra = shellInit;
    programs.zsh.initExtra = shellInit;
    programs.fish.interactiveShellInit = fishInit;

    xdg.configFile = {
      # aichat: OpenRouter via an openai-compatible client honoring baseUrl.
      # The client is named "openrouter", so aichat reads OPENROUTER_API_KEY.
      "aichat/config.yaml".text = ''
        model: openrouter:${aichatModel}
        save: true
        keybindings: emacs
        clients:
          - type: openai-compatible
            name: openrouter
            api_base: ${baseUrl}
            models:
        ${aichatModelsYaml}
      '';

      # Routing policy export.
      "marchyo/ai-routing.json".text = routingJson;
    }
    // bucketRoleFiles;

    # pi: JSON settings + OpenRouter provider extension.
    home.file = {
      ".pi/agent/settings.json".text = builtins.toJSON {
        defaultProvider = "openrouter";
        defaultModel = "openrouter/${piModel}";
        defaultThinkingLevel = "medium";
      };
      ".pi/agent/extensions/marchyo-openrouter.ts".text = piProviderExtension;
    };
  };
}
