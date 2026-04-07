# Weekly activity analysis: Ollama + PrefixSpan + LLM report.
#
# Runs a Python script on a weekly user timer that:
#   1. Tokenises recent atuin history into per-session command sequences
#   2. Mines frequent sub-sequences via PrefixSpan
#   3. Sends only the aggregated patterns (never raw history) to a local
#      Ollama model for automation suggestions, written as an org-mode file.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  aCfg = cfg.analysis;

  ollamaPackage =
    if aCfg.ollamaAcceleration == "cuda" then
      pkgs.ollama-cuda
    else if aCfg.ollamaAcceleration == "rocm" then
      pkgs.ollama-rocm
    else
      pkgs.ollama;

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.requests
    ps.prefixspan
  ]);

  analysisScript = pkgs.writeTextFile {
    name = "marchyo-tracking-analyze.py";
    executable = true;
    text = ''
      #!${pythonEnv}/bin/python
      """Weekly activity analysis: mine shell command patterns, let a local
      LLM interpret them. Output is an org-mode report under ~/org/."""
      import sqlite3, datetime, pathlib, os, sys
      try:
          import requests
          from prefixspan import PrefixSpan
      except ImportError as e:
          print(f"missing dependency: {e}", file=sys.stderr)
          sys.exit(0)

      ATUIN_DB = pathlib.Path.home() / ".local/share/atuin/history.db"
      REPORT   = pathlib.Path.home() / "org/activity-report.org"
      OLLAMA   = "http://127.0.0.1:11434/api/generate"
      MODEL    = os.environ.get("MARCHYO_TRACKING_MODEL", "${aCfg.model}")

      def tokenize(cmd: str) -> str:
          parts = cmd.strip().split()
          if not parts:
              return "empty"
          if len(parts) > 1 and not parts[1].startswith("-"):
              return f"{parts[0]}_{parts[1]}"
          return parts[0]

      def load_sessions(days: int = 7):
          if not ATUIN_DB.exists():
              return []
          cutoff = int((datetime.datetime.now() - datetime.timedelta(days=days)).timestamp() * 1e9)
          con = sqlite3.connect(str(ATUIN_DB))
          try:
              rows = con.execute(
                  "SELECT session, command FROM history WHERE timestamp > ? ORDER BY timestamp",
                  (cutoff,),
              ).fetchall()
          finally:
              con.close()
          sessions: dict[str, list[str]] = {}
          for sess, cmd in rows:
              sessions.setdefault(sess, []).append(tokenize(cmd))
          return list(sessions.values())

      def mine(sessions, min_support: int = 5, min_len: int = 2):
          if not sessions:
              return []
          ps = PrefixSpan(sessions)
          return [p for p in ps.frequent(min_support) if len(p[1]) >= min_len]

      def ask_llm(patterns) -> str:
          if not patterns:
              return "* No frequent patterns found this week.\n"
          top = sorted(patterns, reverse=True)[:20]
          pattern_text = "\n".join(
              f"{i+1}. [{count} times] {' \u2192 '.join(seq)}"
              for i, (count, seq) in enumerate(top)
          )
          prompt = (
              "You are analysing a developer's shell command patterns from the past week.\n\n"
              "## Pre-mined frequent command sequences:\n"
              f"{pattern_text}\n\n"
              "For each pattern that represents a real workflow (not noise):\n"
              "1. Name the workflow\n"
              "2. Write a shell function or script that automates it\n"
              "3. Estimate weekly time savings in minutes\n"
              "4. Flag if this should become a Nix-packaged tool instead.\n\n"
              "Output in org-mode with * headlines and #+begin_src bash blocks.\n"
          )
          try:
              r = requests.post(
                  OLLAMA,
                  json={
                      "model": MODEL,
                      "prompt": prompt,
                      "stream": False,
                      "options": {"temperature": 0.3, "num_ctx": 8192},
                  },
                  timeout=600,
              )
              r.raise_for_status()
              return r.json().get("response", "* LLM returned no response\n")
          except Exception as exc:
              return f"* LLM call failed: {exc}\n"

      def main() -> None:
          sessions = load_sessions(days=7)
          patterns = mine(sessions)
          report = ask_llm(patterns)
          REPORT.parent.mkdir(parents=True, exist_ok=True)
          header = (
              f"#+TITLE: Activity Report {datetime.date.today()}\n"
              f"#+DATE: {datetime.datetime.now().isoformat()}\n\n"
          )
          REPORT.write_text(header + report)

      if __name__ == "__main__":
          main()
    '';
  };
in
{
  config = lib.mkIf (cfg.enable && aCfg.enable) {
    services.ollama = {
      enable = true;
      package = ollamaPackage;
      host = "127.0.0.1";
      port = 11434;
      loadModels = [ aCfg.model ];
    };

    environment.systemPackages = [
      pythonEnv
      analysisScript
    ];

    systemd.user.services.marchyo-tracking-weekly-analysis = {
      description = "Marchyo tracking: weekly activity analysis";
      after = [ "ollama.service" ];
      wants = [ "ollama.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${analysisScript}";
      };
    };

    systemd.user.timers.marchyo-tracking-weekly-analysis = {
      description = "Marchyo tracking: weekly analysis timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun *-*-* 09:00:00";
        Persistent = true;
        Unit = "marchyo-tracking-weekly-analysis.service";
      };
    };
  };
}
