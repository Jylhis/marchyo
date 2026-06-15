# Per-user MCP tool servers for the AI clients.
#
# Enabled when marchyo.ai.enable && marchyo.ai.mcp.enable. Wires mcp-nixos (real
# NixOS package/option lookups — kills hallucinated attr names) into claude-code
# by merging an mcpServers entry into ~/.claude.json (preserving existing state,
# mirroring modules/home/tracking/claude-code.nix's jq merge). mcp-nixos runs via
# `uvx` (fetched from PyPI on first use); `uv` is installed for that.
#
# pi/aichat MCP wiring is intentionally omitted for now (their MCP support is less
# standardized in the pinned versions); they get skills via the Agent Skills
# standard and roles instead (see ai-skills.nix).
{
  osConfig ? { },
  lib,
  pkgs,
  ...
}:
let
  ai = import ../../lib/ai.nix osConfig;
  mcp = ai.aiCfg.mcp or { };
  enabled = ai.featureEnabled "mcp" true;
  nixosEnabled = mcp.nixos.enable or true;

  servers = lib.optionalAttrs nixosEnabled {
    mcp-nixos = {
      command = "${pkgs.uv}/bin/uvx";
      args = [ "mcp-nixos" ];
    };
  };
  serversJson = builtins.toJSON servers;
in
{
  config = lib.mkIf enabled {
    home.packages = [ pkgs.uv ];

    home.activation.marchyoClaudeMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "$HOME/.claude"
      cfg="$HOME/.claude.json"
      tmp="$cfg.tmp"
      servers='${serversJson}'
      if [ -f "$cfg" ]; then
        if ${pkgs.jq}/bin/jq --argjson s "$servers" '.mcpServers = ((.mcpServers // {}) + $s)' "$cfg" > "$tmp"; then
          run mv "$tmp" "$cfg"
        else
          echo "marchyo: ~/.claude.json is not valid JSON; leaving it untouched" >&2
          rm -f "$tmp"
        fi
      else
        ${pkgs.jq}/bin/jq -n --argjson s "$servers" '{mcpServers: $s}' > "$tmp"
        run mv "$tmp" "$cfg"
      fi
    '';
  };
}
