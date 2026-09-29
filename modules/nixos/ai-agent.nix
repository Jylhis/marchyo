# AI coding-agent CLI, selected by marchyo.defaults.aiAgent. Dev-oriented, so
# gated on marchyo.development.enable (not the desktop). Installs only the
# chosen agent and points $AI_AGENT at its command, so binds/scripts can launch
# "the configured agent" without hardcoding a name. Default is null (install
# none), so this stays inert unless a host opts in.
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

  # The command each package exposes ($AI_AGENT / launcher target).
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
