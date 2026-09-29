{
  helpers,
  lib,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;

  hasClaude = cfg: builtins.any (p: lib.getName p == "claude-code") cfg.environment.systemPackages;
  aiVar = cfg: cfg.environment.sessionVariables.AI_AGENT or null;
in
{
  # development + a picked agent: the CLI installs and $AI_AGENT points at it.
  eval-ai-agent-picked =
    testNixOSCheck "ai-agent-picked" (cfg: hasClaude cfg && aiVar cfg == "claude")
      (withTestUser {
        marchyo.development.enable = true;
        marchyo.defaults.aiAgent = "claude-code";
      });

  # development on but no agent picked (default null): nothing installed.
  eval-ai-agent-none =
    testNixOSCheck "ai-agent-none" (cfg: !(hasClaude cfg) && aiVar cfg == null)
      (withTestUser {
        marchyo.development.enable = true;
      });

  # Agent picked but development off: inert.
  eval-ai-agent-no-dev = testNixOSCheck "ai-agent-no-dev" (cfg: !(hasClaude cfg)) (withTestUser {
    marchyo.defaults.aiAgent = "claude-code";
  });
}
