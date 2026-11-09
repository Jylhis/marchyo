# Installs the Marchyo agent skills (packages/marchyo-agent-skills) into the
# skill directories of Claude Code, Codex and opencode. Accounts from
# `marchyo agent account` link their skills directory to the primary home, so
# the same files serve them. Option: marchyo.ai.skills.enable.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  mc = osConfig.marchyo or { };
  enabled = pkgs.stdenv.hostPlatform.isLinux && (((mc.ai or { }).skills or { }).enable or false);

  package = pkgs.marchyo-agent-skills;
  root = "${package}/share/marchyo/skills";

  linksUnder =
    dir:
    lib.listToAttrs (
      map (n: lib.nameValuePair "${dir}/${n}" { source = "${root}/${n}"; }) package.skillNames
    );
in
{
  config = lib.mkIf enabled {
    home.file = linksUnder ".claude/skills" // linksUnder ".codex/skills";
    xdg.configFile = linksUnder "opencode/skills";
    home.sessionVariables.MARCHYO_AGENT_SKILLS = root;
  };
}
