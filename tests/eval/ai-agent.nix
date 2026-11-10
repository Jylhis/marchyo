{ lib, ... }:
let
  hasClaude = cfg: builtins.any (p: lib.getName p == "claude-code") cfg.environment.systemPackages;
  aiVar = cfg: cfg.environment.sessionVariables.AI_AGENT or null;
in
{
  refs = {
    # development + a picked agent: the CLI installs and $AI_AGENT points at it.
    dev-tweaks.eval-ai-agent-picked = cfg: hasClaude cfg && aiVar cfg == "claude";

    # development on but no agent picked (default null): nothing installed.
    headless-dev.eval-ai-agent-none = cfg: !(hasClaude cfg) && aiVar cfg == null;

    # Agent picked but development off: inert.
    headless-tweaks.eval-ai-agent-no-dev = cfg: !(hasClaude cfg);
  };

  refConfig = {
    dev-tweaks.marchyo.defaults.aiAgent = "claude-code";
    headless-tweaks.marchyo.defaults.aiAgent = "claude-code";
  };
}
