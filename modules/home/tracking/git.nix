# Per-user git tracking hook.
#
# Writes a post-commit hook to ~/.config/marchyo/git-hooks/ that appends
# commit metadata to the tracking JSONL stream. The hook is NOT wired
# into core.hooksPath automatically to avoid overriding per-repo hooks.
# To activate globally, set:
#   programs.git.extraConfig.core.hooksPath = "~/.config/marchyo/git-hooks";
# or symlink into individual repos.
{
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  trackingCfg = osConfig.marchyo.tracking or { };
  enabled = (trackingCfg.enable or false) && (trackingCfg.git.enable or false);
  dataDir = trackingCfg.dataDir or ".local/share/personal-data";
in
{
  config = lib.mkIf enabled {
    xdg.configFile."marchyo/git-hooks/post-commit" = {
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        set -eu
        OUT="$HOME/${dataDir}"
        ${pkgs.coreutils}/bin/mkdir -p "$OUT"
        repo=$(${pkgs.coreutils}/bin/basename "$(${pkgs.git}/bin/git rev-parse --show-toplevel)")
        branch=$(${pkgs.git}/bin/git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        hash=$(${pkgs.git}/bin/git rev-parse --short HEAD)
        ts=$(${pkgs.git}/bin/git log -1 --format=%aI)
        msg=$(${pkgs.git}/bin/git log -1 --format=%s)
        ${pkgs.jq}/bin/jq -cn \
          --arg ts "$ts" --arg repo "$repo" --arg branch "$branch" \
          --arg hash "$hash" --arg msg "$msg" \
          '{type:"git-commit",ts:$ts,repo:$repo,branch:$branch,hash:$hash,msg:$msg}' \
          >> "$OUT/git-activity.jsonl"
      '';
    };
  };
}
