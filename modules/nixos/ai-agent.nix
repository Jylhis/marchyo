# Installs the agents in marchyo.ai.agents plus the default agent, and points
# $AI_AGENT at the default agent's command so binds/scripts can launch the
# configured agent without hardcoding a name. With marchyo.ai.accounts.enable,
# claude, codex and grok start as the account `marchyo agent account` selects.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo;
  agent = cfg.defaults.aiAgent;
  defaultActive = cfg.development.enable && agent != null;

  agentPackages = {
    inherit (pkgs) claude-code codex opencode;
    grok = pkgs.grok;
    gemini = pkgs.gemini-cli;
    copilot = pkgs.github-copilot-cli;
  };

  agentCommands = {
    claude-code = "claude";
    codex = "codex";
    opencode = "opencode";
  };

  # Agents with account homes: the provider name the CLI and registry use.
  accountProviders = {
    claude-code = "claude";
    codex = "codex";
    grok = "grok";
  };

  agentExec = pkgs.writeShellScript "marchyo-agent-exec" (
    builtins.replaceStrings [ "@jq@" ] [ (lib.getExe pkgs.jq) ] (builtins.readFile ./ai-agent-exec.sh)
  );

  # The package with its main program replaced by the account wrapper; the
  # real one stays as <program>-unwrapped.
  withAccounts =
    provider: pkg:
    let
      program = pkg.meta.mainProgram;
      real = lib.getExe pkg;
    in
    pkgs.symlinkJoin {
      pname = lib.getName pkg;
      version = lib.getVersion pkg;
      paths = [ pkg ];
      postBuild = ''
        rm "$out/bin/${program}"
        ln -s ${real} "$out/bin/${program}-unwrapped"
        cat > "$out/bin/${program}" <<EOF
        #!${pkgs.runtimeShell}
        exec ${agentExec} ${provider} ${real} "\$@"
        EOF
        chmod +x "$out/bin/${program}"
      '';
      passthru = {
        unwrapped = pkg;
        accountProvider = provider;
        unwrappedProgram = "${program}-unwrapped";
      };
      inherit (pkg) meta;
    };

  packageFor =
    a:
    if cfg.ai.accounts.enable && accountProviders ? ${a} then
      withAccounts accountProviders.${a} agentPackages.${a}
    else
      agentPackages.${a};

  agents = lib.unique (cfg.ai.agents ++ lib.optional defaultActive agent);
in
{
  config = lib.mkMerge [
    (lib.mkIf (agents != [ ]) {
      environment.systemPackages = map packageFor agents;
    })
    (lib.mkIf defaultActive {
      environment.sessionVariables.AI_AGENT = agentCommands.${agent};
    })
  ];
}
