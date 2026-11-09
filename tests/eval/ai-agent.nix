{
  helpers,
  lib,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;

  count = name: cfg: lib.count (p: lib.getName p == name) cfg.environment.systemPackages;
  has = name: cfg: count name cfg > 0;
  hasClaude = has "claude-code";
  aiVar = cfg: cfg.environment.sessionVariables.AI_AGENT or null;
  pkgNamed = name: cfg: lib.findFirst (p: lib.getName p == name) null cfg.environment.systemPackages;
  wrappedAs =
    name: provider: cfg:
    let
      p = pkgNamed name cfg;
    in
    p != null && p ? unwrapped && (p.accountProvider or null) == provider;
  unwrapped =
    name: cfg:
    let
      p = pkgNamed name cfg;
    in
    p != null && !(p ? unwrapped);
  threeAgents = {
    marchyo.ai.agents = [
      "claude-code"
      "codex"
      "grok"
      "opencode"
    ];
  };
in
{
  # Accounts are on by default: claude, codex and grok run through the
  # account wrapper under their own package names; opencode has no accounts.
  eval-ai-accounts-wrappers = testNixOSCheck "ai-accounts-wrappers" (
    cfg:
    wrappedAs "claude-code" "claude" cfg
    && wrappedAs "codex" "codex" cfg
    && wrappedAs "grok" "grok" cfg
    && unwrapped "opencode" cfg
    && (pkgNamed "claude-code" cfg).unwrappedProgram == "claude-unwrapped"
    && lib.getExe (pkgNamed "codex" cfg) != lib.getExe (pkgNamed "codex" cfg).unwrapped
  ) (withTestUser threeAgents);

  # Turned off, the plain packages install.
  eval-ai-accounts-disabled = testNixOSCheck "ai-accounts-disabled" (
    cfg: unwrapped "claude-code" cfg && unwrapped "codex" cfg && unwrapped "grok" cfg
  ) (withTestUser (lib.recursiveUpdate threeAgents { marchyo.ai.accounts.enable = false; }));

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

  # The agents list installs every entry, with or without development.
  eval-ai-agents-list =
    testNixOSCheck "ai-agents-list"
      (cfg: hasClaude cfg && has "codex" cfg && has "opencode" cfg && aiVar cfg == null)
      (withTestUser {
        marchyo.ai.agents = [
          "claude-code"
          "codex"
          "opencode"
        ];
      });

  # The default agent joins the list once, and $AI_AGENT still names it.
  eval-ai-agents-default-merged =
    testNixOSCheck "ai-agents-default-merged" (cfg: count "codex" cfg == 1 && aiVar cfg == "codex")
      (withTestUser {
        marchyo.development.enable = true;
        marchyo.defaults.aiAgent = "codex";
        marchyo.ai.agents = [ "codex" ];
      });
}
