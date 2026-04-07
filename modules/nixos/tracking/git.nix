# Per-user git activity daily scan timer.
#
# Walks ~/<scanRoot> up to 4 levels deep, finds .git directories, and
# appends the day's commits by the configured git user.email to a JSONL
# stream in the tracking data dir.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  gitCfg = cfg.git;

  scanScript = pkgs.writeShellScript "marchyo-tracking-git-scan" ''
    set -eu
    OUT="$HOME/${cfg.dataDir}"
    ${pkgs.coreutils}/bin/mkdir -p "$OUT"
    EMAIL=$(${pkgs.git}/bin/git config --global --get user.email || echo "")
    if [ -z "$EMAIL" ]; then
      exit 0
    fi
    SCAN_ROOT="$HOME/${gitCfg.scanRoot}"
    if [ ! -d "$SCAN_ROOT" ]; then
      exit 0
    fi
    ${pkgs.findutils}/bin/find "$SCAN_ROOT" -maxdepth 4 -name .git -type d 2>/dev/null \
    | while read -r gitdir; do
      repo=$(${pkgs.coreutils}/bin/dirname "$gitdir")
      name=$(${pkgs.coreutils}/bin/basename "$repo")
      branch=$(${pkgs.git}/bin/git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
      ${pkgs.git}/bin/git -C "$repo" log --since="1 day ago" \
        --author="$EMAIL" \
        --format="%aI%x09%h%x09%s" 2>/dev/null \
      | while IFS=$'\t' read -r ts hash msg; do
        ${pkgs.jq}/bin/jq -cn \
          --arg ts "$ts" --arg repo "$name" --arg branch "$branch" \
          --arg hash "$hash" --arg msg "$msg" \
          '{type:"git",ts:$ts,repo:$repo,branch:$branch,hash:$hash,msg:$msg}' \
          >> "$OUT/git-activity.jsonl"
      done
    done
  '';
in
{
  config = lib.mkIf (cfg.enable && gitCfg.enable) {
    systemd.user.services.marchyo-tracking-git-scan = {
      description = "Marchyo tracking: daily git activity scan";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${scanScript}";
      };
    };

    systemd.user.timers.marchyo-tracking-git-scan = {
      description = "Marchyo tracking: daily git scan timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "marchyo-tracking-git-scan.service";
      };
    };

    # Reference post-commit hook installed under /etc for users to symlink
    # into their ~/.config/git/hooks (or set core.hooksPath). Not wired up
    # automatically so that existing per-user hook configurations are not
    # silently overridden.
    environment.etc."marchyo/git-hooks/post-commit" = {
      mode = "0755";
      text = ''
        #!${pkgs.runtimeShell}
        set -eu
        OUT="$HOME/${cfg.dataDir}"
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
