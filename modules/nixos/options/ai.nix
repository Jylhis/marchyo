# marchyo.ai.* — BYOK (bring-your-own-key) AI tooling and desktop integration.
#
# Declaration-only (auto-discovered). Keep this file platform-neutral with no
# Linux-only package references: modules/darwin/default.nix imports
# ../nixos/options, so every option here is evaluated on darwin too. All package
# wiring lives in the impl modules (modules/nixos/ai.nix, modules/home/*).
{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;

  # task bucket -> { model; fallbacks; }
  taskSubmodule = types.submodule {
    options = {
      model = mkOption {
        type = types.str;
        description = "Primary OpenRouter model slug for this task bucket.";
      };
      fallbacks = mkOption {
        type = types.listOf types.str;
        default = [ "openrouter/auto" ];
        description = ''
          Ordered OpenRouter fallback slugs. Consumed as OpenRouter's native
          `models` array (auto-failover on error/rate-limit/downtime).
        '';
      };
    };
  };
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
          Fallback default model slug used when routing is disabled. When
          marchyo.ai.routing.enable is true, per-tool models come from the
          routing table instead.
        '';
      };
    };

    tooling.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Install the AI client CLIs (aichat, pi, claude-code) for the user and
        wire the OpenRouter-backed ones to the provider. On by default when
        marchyo.ai is enabled. (claude-code speaks the Anthropic API and is not
        wired to OpenRouter; it comes from llm-agents.nix, which also packages
        codex/gemini-cli/goose/crush/… via the overlay for future opt-in.)
      '';
    };

    # --- Task-based model routing -------------------------------------------
    routing = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Route different tasks to different models. Defaults pin the
          frontier/reasoning buckets and lean on openrouter/auto + the
          :nitro/:floor variant suffixes elsewhere so quarterly slug churn is
          absorbed. All defaults are mkDefault — override any bucket. Slugs are
          starting points; verify against OpenRouter's live model list.
        '';
      };

      tasks = mkOption {
        type = types.attrsOf taskSubmodule;
        description = "Task bucket -> model + fallback chain.";
        default = {
          frontier = {
            model = lib.mkDefault "anthropic/claude-opus-4.8";
            fallbacks = lib.mkDefault [
              "openai/gpt-5.5"
              "google/gemini-3.1-pro"
              "openrouter/auto"
            ];
          };
          everydayCoding = {
            model = lib.mkDefault "anthropic/claude-sonnet-4.6";
            fallbacks = lib.mkDefault [
              "openai/gpt-5.5"
              "openrouter/auto"
            ];
          };
          fast = {
            model = lib.mkDefault "anthropic/claude-haiku-4.5:nitro";
            fallbacks = lib.mkDefault [
              "google/gemini-3.1-flash:nitro"
              "openrouter/auto"
            ];
          };
          reasoning = {
            model = lib.mkDefault "anthropic/claude-fable-5";
            fallbacks = lib.mkDefault [
              "google/gemini-3.1-pro"
              "openrouter/auto"
            ];
          };
          summarize = {
            model = lib.mkDefault "anthropic/claude-haiku-4.5";
            fallbacks = lib.mkDefault [
              "x-ai/grok-4.1-fast"
              "openrouter/auto"
            ];
          };
          longContext = {
            model = lib.mkDefault "minimax/minimax-m3";
            fallbacks = lib.mkDefault [
              "google/gemini-3.1-flash"
              "openrouter/auto"
            ];
          };
          budget = {
            model = lib.mkDefault "deepseek/deepseek-v3.2:floor";
            fallbacks = lib.mkDefault [ "openrouter/auto" ];
          };
          # Placeholder until local inference (ollama) lands.
          local = {
            model = lib.mkDefault "openrouter/auto";
            fallbacks = lib.mkDefault [ "openrouter/auto" ];
          };
        };
      };

      tools = mkOption {
        type = types.attrsOf types.str;
        default = {
          aichat = "everydayCoding";
          pi = "everydayCoding";
        };
        description = ''
          Which task bucket each OpenRouter-backed client defaults to. (claude-code
          is Anthropic-native and not routed here.)
        '';
      };
    };

    # --- OpenViking context / memory layer ----------------------------------
    context = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Install OpenViking (`ov`), a local context database for AI agents, and
          point its embeddings at OpenRouter. Data stays under workspacePath.
        '';
      };
      workspacePath = mkOption {
        type = types.str;
        default = ".openviking/workspace";
        description = "OpenViking workspace dir, relative to $HOME (kept local/inspectable).";
      };
      service.enable = mkOption {
        type = types.bool;
        default = false;
        description = "Run the OpenViking HTTP server as a per-user systemd service.";
      };
      embeddingModel = mkOption {
        type = types.str;
        default = "openai/text-embedding-3-small";
        description = "OpenRouter embedding model slug used by OpenViking.";
      };
    };

    # --- Marchyo-specific skills (Agent Skills standard) --------------------
    skills = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Install a curated, vendored subset of the Jylhis/skills marketplace as
          Agent Skills (SKILL.md), surfaced to all clients (claude-code + pi
          share the standard) and loaded into OpenViking when context is enabled.
        '';
      };
      clients = mkOption {
        type = types.listOf (
          types.enum [
            "claude-code"
            "pi"
            "aichat"
          ]
        );
        default = [
          "claude-code"
          "pi"
          "aichat"
        ];
        description = "Clients to surface vendored skills to (native fallback per client).";
      };
    };

    # --- MCP tools ----------------------------------------------------------
    mcp = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Wire MCP tool servers (e.g. mcp-nixos, for grounded NixOS attr/option
          lookups) into the MCP-capable clients.
        '';
      };
      nixos.enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the mcp-nixos server (run via uvx).";
      };
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
