# Points $AI_AGENT at the chosen agent's command so binds/scripts can launch the
# configured agent without hardcoding a name. Default null installs none.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
  agent = cfg.defaults.aiAgent;

  agentPackages = {
    inherit (pkgs) claude-code;
    inherit (pkgs) codex;
    inherit (pkgs) opencode;
  };

  agentCommands = {
    claude-code = "claude";
    codex = "codex";
    opencode = "opencode";
  };
in
{
  config = lib.mkIf (cfg.development.enable && agent != null) {
    environment.systemPackages = [ agentPackages.${agent} ];
    environment.sessionVariables.AI_AGENT = agentCommands.${agent};
  };
}
