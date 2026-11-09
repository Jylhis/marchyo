# Crash capture: follows systemd-coredump in the journal and offers an AI
# diagnosis. Options live in modules/nixos/options/ai.nix.
{
  lib,
  pkgs,
  osConfig ? { },
  ...
}:
let
  mc = osConfig.marchyo or { };
  cfg = (mc.ai or { }).crashCapture or { };
  enabled = pkgs.stdenv.hostPlatform.isLinux && (mc.desktop.enable or false) && (cfg.enable or false);

  watcher = pkgs.writeShellApplication {
    name = "marchyo-crash-watch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.libnotify
      pkgs.systemd
      pkgs.marchyo-cli
    ];
    text = builtins.readFile ./crash-watch.sh;
  };

  # Through a file: Environment= mangles backslashes, % and spaces.
  ignoreFile = pkgs.writeText "marchyo-crash-ignore" cfg.ignore;

  aiAgent = (osConfig.environment.sessionVariables or { }).AI_AGENT or null;
  skills = "${pkgs.marchyo-agent-skills}/share/marchyo/skills";
in
{
  config = lib.mkIf enabled {
    systemd.user.services.marchyo-crash-watch = {
      Unit = {
        Description = "Offer an AI diagnosis for crashed programs";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe watcher;
        Restart = "on-failure";
        # The diagnosing agent runs in its own transient unit, so none of this
        # reaches it. journalctl, notify-send and systemd-run need only files
        # and the session bus.
        NoNewPrivileges = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictAddressFamilies = "AF_UNIX";
        TasksMax = 64;
        MemoryMax = "512M";
        Environment = [
          "MARCHYO_CRASH_IGNORE_FILE=${ignoreFile}"
          "MARCHYO_CRASH_DEDUPE_SECONDS=${toString cfg.dedupeSeconds}"
          "MARCHYO_AGENT_SKILLS=${skills}"
        ]
        ++ lib.optional (aiAgent != null) "AI_AGENT=${aiAgent}";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
