# Per-user Marchyo Agent Skills, surfaced to all clients.
#
# Enabled when marchyo.ai.enable && marchyo.ai.skills.enable. Installs the
# vendored Agent Skills (SKILL.md dirs under ./ai-skills/skills) to each selected
# client. claude-code and pi both consume the Agent Skills standard natively
# (~/.claude/skills, ~/.pi/agent/skills); aichat gets each skill as a role.
#
# OpenViking has no MCP/native skill-consumption path, so it is not a delivery
# target here; when context is enabled it can index the skill dirs via
# `ov add-resource ~/.claude/skills` (documented in docs/configuration/ai.mdx).
#
# To vendor more skills (e.g. from the Jylhis/skills marketplace), drop additional
# `<name>/SKILL.md` dirs under ./ai-skills/skills — they are auto-discovered here.
{
  osConfig ? { },
  lib,
  ...
}:
let
  aiCfg = (osConfig.marchyo or { }).ai or { };
  skillsCfg = aiCfg.skills or { };
  enabled = (aiCfg.enable or false) && (skillsCfg.enable or true);
  clients =
    skillsCfg.clients or [
      "claude-code"
      "pi"
      "aichat"
    ];
  has = c: builtins.elem c clients;

  skillsDir = ./ai-skills/skills;
  skillNames = builtins.attrNames (
    lib.filterAttrs (_: t: t == "directory") (builtins.readDir skillsDir)
  );

  mkDirLinks =
    prefix:
    lib.listToAttrs (
      map (
        n:
        lib.nameValuePair "${prefix}/${n}" {
          source = skillsDir + "/${n}";
          recursive = true;
        }
      ) skillNames
    );

  mkRoleLinks =
    prefix:
    lib.listToAttrs (
      map (
        n:
        lib.nameValuePair "${prefix}/${n}.md" {
          source = skillsDir + "/${n}/SKILL.md";
        }
      ) skillNames
    );
in
{
  config = lib.mkIf enabled {
    home.file = lib.mkMerge [
      (lib.mkIf (has "claude-code") (mkDirLinks ".claude/skills"))
      (lib.mkIf (has "pi") (mkDirLinks ".pi/agent/skills"))
    ];
    xdg.configFile = lib.mkIf (has "aichat") (mkRoleLinks "aichat/roles");
  };
}
