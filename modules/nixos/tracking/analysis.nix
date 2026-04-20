# Weekly activity analysis: llama-server (llama.cpp) + PrefixSpan + LLM report.
#
# Runs a Python script on a weekly user timer that:
#   1. Tokenises recent atuin history into per-session command sequences
#   2. Mines frequent sub-sequences via PrefixSpan
#   3. Sends only the aggregated patterns (never raw history) to a local
#      llama-server instance for automation suggestions, written as an org-mode file.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  aCfg = cfg.analysis;

  llamaCppPackage =
    if aCfg.acceleration == "cuda" then
      pkgs.llama-cpp.override { cudaSupport = true; }
    else if aCfg.acceleration == "rocm" then
      pkgs.llama-cpp.override { rocmSupport = true; }
    else
      pkgs.llama-cpp;

  pythonEnv = pkgs.python3.withPackages (ps: [
    ps.requests
  ]);

  analysisScript = pkgs.writeTextFile {
    name = "marchyo-tracking-analyze.py";
    executable = true;
    text = ''
      #!${pythonEnv}/bin/python
      """Weekly activity analysis: mine shell command patterns, let a local
      LLM interpret them. Output is an org-mode report under ~/org/."""
      import sqlite3, datetime, pathlib, os, time, requests

      ATUIN_DB = pathlib.Path.home() / ".local/share/atuin/history.db"
      REPORT   = pathlib.Path.home() / "org/activity-report.org"
      LLAMA    = "http://127.0.0.1:8012/completion"

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
          # Read-only open: avoids locking the active atuin daemon's DB and
          # guarantees the analysis cannot modify history.
          con = sqlite3.connect(f"file:{ATUIN_DB}?mode=ro", uri=True)
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

      def _prefixspan(sequences, min_support):
          """Inline PrefixSpan frequent subsequence mining."""
          results = []

          def _mine(prefix, db):
              counts = {}
              for seq in db:
                  seen = set()
                  for item in seq:
                      if item not in seen:
                          counts[item] = counts.get(item, 0) + 1
                          seen.add(item)
              for item, count in counts.items():
                  if count >= min_support:
                      new_prefix = prefix + [item]
                      results.append((count, new_prefix))
                      projected = [seq[seq.index(item) + 1:] for seq in db if item in seq]
                      _mine(new_prefix, projected)

          _mine([], sequences)
          return results

      def mine(sessions, min_support: int = 5, min_len: int = 2):
          if not sessions:
              return []
          return [p for p in _prefixspan(sessions, min_support) if len(p[1]) >= min_len]

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
          for attempt in range(3):
              try:
                  r = requests.post(
                      LLAMA,
                      json={
                          "prompt": prompt,
                          "stream": False,
                          "temperature": 0.3,
                          "n_predict": 4096,
                      },
                      timeout=600,
                  )
                  r.raise_for_status()
                  return r.json().get("content", "* LLM returned no response\n")
              except requests.ConnectionError:
                  if attempt < 2:
                      time.sleep(10)
                      continue
                  return "* LLM call failed: llama-server not reachable after 3 attempts\n"
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
    systemd.services.marchyo-llama-server = {
      description = "llama-server for marchyo tracking analysis";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${llamaCppPackage}/bin/llama-server -m ${aCfg.model} --host 127.0.0.1 --port 8012 -c 8192";
        Restart = "on-failure";
        RestartSec = 5;
        DynamicUser = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        NoNewPrivileges = true;
      };
    };

    systemd.user.services.marchyo-tracking-weekly-analysis = {
      description = "Marchyo tracking: weekly activity analysis";
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
