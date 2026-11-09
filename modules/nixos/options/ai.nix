{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.marchyo;
  agentInUse = cfg.ai.agents != [ ] || (cfg.development.enable && cfg.defaults.aiAgent != null);
in
{
  options.marchyo.ai.agents = mkOption {
    type = types.listOf (
      types.enum [
        "claude-code"
        "codex"
        "opencode"
        "grok"
        "gemini"
        "copilot"
      ]
    );
    default = [ ];
    example = [
      "claude-code"
      "codex"
    ];
    description = ''
      AI coding-agent CLIs to install. `marchyo.defaults.aiAgent` (with
      `marchyo.development.enable`) is added to this list automatically. The
      agents panel and the `marchyo.agents` bar widget show the usage limits
      of the agents signed in on this machine. The CLIs are network tools you
      still have to authenticate before use.
    '';
  };

  options.marchyo.ai.local = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Run local language models with Ollama. Marchyo picks the Ollama build
        that matches the GPU vendors in `marchyo.graphics.vendors`, and
        points the opencode agent at the server when
        `marchyo.defaults.aiAgent` is "opencode".
      '';
    };

    models = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "qwen3:8b"
        "llama3.2"
      ];
      description = ''
        Models to pull when the server starts (`services.ollama.loadModels`).
        The opencode provider lists the same models.
      '';
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address the Ollama server listens on.";
    };

    port = mkOption {
      type = types.port;
      default = 11434;
      description = "Port the Ollama server listens on.";
    };

    acceleration = mkOption {
      type = types.nullOr (
        types.enum [
          "cuda"
          "rocm"
          "cpu"
        ]
      );
      default = null;
      description = ''
        Ollama build to use. `null` selects it from `marchyo.graphics`: CUDA
        when nvidia is a vendor (NVIDIA wins on mixed machines), ROCm when
        amd is a vendor and `marchyo.graphics.amd.rocm.enable` is set, else
        the default Ollama package.
      '';
    };
  };
  options.marchyo.ai.accounts.enable = mkOption {
    type = types.bool;
    default = true;
    example = false;
    description = ''
      Install the installed Claude Code, Codex and Grok CLIs behind a wrapper
      that starts each session as the account chosen with
      `marchyo agent account use` (through `CLAUDE_CONFIG_DIR`, `CODEX_HOME`
      or `GROK_HOME`). Subprocesses keep the session's account. The
      unwrapped CLIs stay available as `claude-unwrapped`, `codex-unwrapped`
      and `grok-unwrapped`. Has no effect while none of these agents is
      installed.
    '';
  };

  options.marchyo.ai.skills.enable = mkOption {
    type = types.bool;
    default = agentInUse;
    defaultText = lib.literalExpression ''
      config.marchyo.ai.agents != [ ]
      || (config.marchyo.development.enable && config.marchyo.defaults.aiAgent != null)
    '';
    example = false;
    description = ''
      Install the Marchyo agent skills (`marchyo`, `marchyo-plugin` and
      `diagnose-crash`) into the skill directories of Claude Code
      (`~/.claude/skills`), Codex (`~/.codex/skills`) and opencode
      (`~/.config/opencode/skills`). Accounts added with `marchyo agent account`
      link their `skills` directory to these, so they see the same skills. On by
      default while an AI coding agent is installed.
    '';
  };

  options.marchyo.ai.crashCapture = {
    enable = mkOption {
      type = types.bool;
      default = cfg.desktop.enable && agentInUse;
      defaultText = lib.literalExpression ''
        config.marchyo.desktop.enable && <an AI coding agent is installed>
      '';
      example = false;
      description = ''
        Follow the journal for systemd-coredump entries of your own processes and
        send a notification with a "Diagnose" action. The action runs
        `marchyo agent crash`, which starts `$AI_AGENT` on the diagnose-crash
        skill. `marchyo toggle crash-capture off` stops the watcher for the
        session.
      '';
    };

    ignore = mkOption {
      type = types.str;
      default = "";
      example = "^(steam|wine.*)$";
      description = ''
        Extended regular expression matched against the executable's basename.
        Crashes of matching programs are not announced. Empty ignores nothing.
      '';
    };

    dedupeSeconds = mkOption {
      type = types.ints.unsigned;
      default = 60;
      description = ''
        A program that keeps crashing is announced at most once in this many
        seconds, so a crash loop does not bury the desktop in notifications.
      '';
    };
  };
}
