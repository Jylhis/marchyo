# Weekly activity analysis: aggregated multi-source report + optional LLM insights.
#
# Runs a Python script on a weekly user timer that:
#   1. Loads data from all enabled tracking collectors (atuin, git, file
#      changes, ActivityWatch, wakapi)
#   2. Produces a structured stats-only org-mode report
#   3. Optionally sends the aggregated stats to a local llama-server for
#      automation suggestions and productivity insights
#
# When marchyo.tracking.analysis.model is null (default), the report is
# stats-only. When a GGUF model path is provided, llama-server is started
# and the report includes an AI Insights section.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.tracking;
  aCfg = cfg.analysis;
  llmEnabled = aCfg.model != null;

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
      """Weekly activity analysis: aggregate all tracking sources into an
      org-mode report. Optionally enriched with local LLM insights."""
      import sqlite3, datetime, pathlib, os, time, json, requests
      from collections import Counter, defaultdict

      ATUIN_DB   = pathlib.Path.home() / ".local/share/atuin/history.db"
      REPORT     = pathlib.Path.home() / "org/activity-report.org"
      DATA_DIR   = pathlib.Path.home() / os.environ.get("MARCHYO_DATA_DIR", ".local/share/personal-data")
      WAKAPI_PORT = int(os.environ.get("MARCHYO_WAKAPI_PORT", "3000"))
      LLM_ENABLED = os.environ.get("MARCHYO_LLM_ENABLED", "0") == "1"
      LLAMA_PORT  = int(os.environ.get("MARCHYO_LLAMA_PORT", "${toString aCfg.port}"))
      LLAMA_URL   = f"http://127.0.0.1:{LLAMA_PORT}/completion"
      DAYS        = 7

      # ── Shell history (atuin) ──────────────────────────────────────────

      def tokenize(cmd: str) -> str:
          parts = cmd.strip().split()
          if not parts:
              return "empty"
          if len(parts) > 1 and not parts[1].startswith("-"):
              return f"{parts[0]}_{parts[1]}"
          return parts[0]

      def load_sessions(days: int = DAYS):
          if not ATUIN_DB.exists():
              return [], {}
          cutoff = int((datetime.datetime.now() - datetime.timedelta(days=days)).timestamp() * 1e9)
          con = sqlite3.connect(f"file:{ATUIN_DB}?mode=ro", uri=True)
          try:
              rows = con.execute(
                  "SELECT session, command, exit_status, duration FROM history WHERE timestamp > ? ORDER BY timestamp",
                  (cutoff,),
              ).fetchall()
          finally:
              con.close()
          sessions: dict[str, list[str]] = {}
          raw_cmds: list[str] = []
          total_duration = 0
          failed = 0
          for sess, cmd, exit_status, duration in rows:
              sessions.setdefault(sess, []).append(tokenize(cmd))
              raw_cmds.append(cmd.strip().split()[0] if cmd.strip() else "empty")
              if exit_status and exit_status != 0:
                  failed += 1
              if duration:
                  total_duration += duration
          cmd_counts = Counter(raw_cmds)
          stats = {
              "total_commands": len(rows),
              "unique_commands": len(set(raw_cmds)),
              "sessions": len(sessions),
              "failed": failed,
              "total_duration_ns": total_duration,
              "top_commands": cmd_counts.most_common(15),
          }
          return list(sessions.values()), stats

      # ── PrefixSpan ────────────────────────────────────────────────────

      def _prefixspan(sequences, min_support):
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

      def mine_patterns(sessions, min_support: int = 5, min_len: int = 2):
          if not sessions:
              return []
          return [p for p in _prefixspan(sessions, min_support) if len(p[1]) >= min_len]

      # ── Git activity ──────────────────────────────────────────────────

      def load_git_activity():
          path = DATA_DIR / "git-activity.jsonl"
          if not path.exists():
              return {}
          cutoff = datetime.datetime.now() - datetime.timedelta(days=DAYS)
          repos: dict[str, dict] = defaultdict(lambda: {"commits": 0, "branches": set(), "messages": []})
          commits_by_day: dict[str, int] = Counter()
          for line in path.read_text().splitlines():
              try:
                  e = json.loads(line)
              except json.JSONDecodeError:
                  continue
              try:
                  ts = datetime.datetime.fromisoformat(e.get("ts", ""))
                  if ts.replace(tzinfo=None) < cutoff:
                      continue
              except (ValueError, TypeError):
                  continue
              repo = e.get("repo", "unknown")
              repos[repo]["commits"] += 1
              repos[repo]["branches"].add(e.get("branch", ""))
              repos[repo]["messages"].append(e.get("msg", ""))
              commits_by_day[ts.strftime("%A")] += 1
          for r in repos.values():
              r["branches"] = list(r["branches"])
          return {
              "repos": dict(repos),
              "total_commits": sum(r["commits"] for r in repos.values()),
              "commits_by_day": dict(commits_by_day),
          }

      # ── File changes ──────────────────────────────────────────────────

      def load_file_changes():
          path = DATA_DIR / "file-changes.jsonl"
          if not path.exists():
              return {}
          cutoff = datetime.datetime.now() - datetime.timedelta(days=DAYS)
          by_dir: dict[str, int] = Counter()
          by_event: dict[str, int] = Counter()
          total = 0
          for line in path.read_text().splitlines():
              try:
                  e = json.loads(line)
              except json.JSONDecodeError:
                  continue
              try:
                  ts = datetime.datetime.fromisoformat(e.get("ts", ""))
                  if ts < cutoff:
                      continue
              except (ValueError, TypeError):
                  pass
              fpath = e.get("path", "")
              parts = pathlib.PurePosixPath(fpath).parts
              top_dir = "/".join(parts[:5]) if len(parts) >= 5 else str(pathlib.PurePosixPath(fpath).parent)
              by_dir[top_dir] += 1
              by_event[e.get("event", "unknown")] += 1
              total += 1
          return {
              "total": total,
              "top_directories": Counter(by_dir).most_common(10),
              "by_event": dict(by_event),
          }

      # ── ActivityWatch ──────────────────────────────────────────────────

      def load_activitywatch():
          try:
              r = requests.get("http://127.0.0.1:5600/api/0/buckets", timeout=5)
              r.raise_for_status()
              buckets = r.json()
          except Exception:
              return {}

          now = datetime.datetime.now(datetime.timezone.utc)
          start = (now - datetime.timedelta(days=DAYS)).isoformat()
          end = now.isoformat()

          app_durations: dict[str, float] = Counter()
          total_active = 0.0
          total_idle = 0.0

          for bucket_id, info in buckets.items():
              btype = info.get("type", "")
              try:
                  events_r = requests.get(
                      f"http://127.0.0.1:5600/api/0/buckets/{bucket_id}/events",
                      params={"start": start, "end": end, "limit": 5000},
                      timeout=10,
                  )
                  events_r.raise_for_status()
                  events = events_r.json()
              except Exception:
                  continue

              if "window" in btype:
                  for ev in events:
                      dur = ev.get("duration", 0)
                      app = ev.get("data", {}).get("app", "unknown")
                      app_durations[app] += dur
                      total_active += dur
              elif "afk" in btype:
                  for ev in events:
                      dur = ev.get("duration", 0)
                      status = ev.get("data", {}).get("status", "")
                      if status == "not-afk":
                          total_active += dur
                      else:
                          total_idle += dur

          return {
              "top_apps": Counter(app_durations).most_common(10),
              "active_hours": round(total_active / 3600, 1),
              "idle_hours": round(total_idle / 3600, 1),
          }

      # ── Wakapi ─────────────────────────────────────────────────────────

      def load_wakapi():
          try:
              end = datetime.date.today()
              start = end - datetime.timedelta(days=DAYS)
              r = requests.get(
                  f"http://127.0.0.1:{WAKAPI_PORT}/api/summary",
                  params={"from": start.isoformat(), "to": end.isoformat()},
                  timeout=10,
              )
              r.raise_for_status()
              data = r.json()
          except Exception:
              return {}

          def extract_top(items, key="name"):
              return [(e.get(key, "?"), round(e.get("total_seconds", 0) / 3600, 1)) for e in items[:10]]

          return {
              "total_hours": round(data.get("cumulative_total", {}).get("seconds", 0) / 3600, 1),
              "projects": extract_top(data.get("projects", [])),
              "languages": extract_top(data.get("languages", [])),
              "editors": extract_top(data.get("editors", [])),
          }

      # ── Report generation ─────────────────────────────────────────────

      def fmt_duration_ns(ns: int) -> str:
          secs = ns // 1_000_000_000
          hrs, rem = divmod(secs, 3600)
          mins = rem // 60
          if hrs:
              return f"{hrs}h {mins}m"
          return f"{mins}m"

      def section_shell(stats: dict, patterns: list) -> str:
          if not stats:
              return "* Shell Activity\nNo shell history found.\n\n"
          lines = [
              "* Shell Activity",
              f"- Commands executed: {stats['total_commands']}",
              f"- Unique commands: {stats['unique_commands']}",
              f"- Sessions: {stats['sessions']}",
              f"- Failed commands: {stats['failed']}",
              f"- Total command time: {fmt_duration_ns(stats['total_duration_ns'])}",
              "",
              "** Top Commands",
          ]
          for cmd, count in stats["top_commands"]:
              lines.append(f"| {cmd} | {count} |")
          lines.append("")
          if patterns:
              top = sorted(patterns, reverse=True)[:15]
              lines.append("** Frequent Sequences")
              for count, seq in top:
                  lines.append(f"- [{count}x] {' -> '.join(seq)}")
          lines.append("")
          return "\n".join(lines) + "\n"

      def section_git(data: dict) -> str:
          if not data or not data.get("repos"):
              return "* Git Activity\nNo git activity recorded.\n\n"
          lines = [
              "* Git Activity",
              f"- Total commits: {data['total_commits']}",
              "",
              "** By Repository",
          ]
          for repo, info in sorted(data["repos"].items(), key=lambda x: -x[1]["commits"]):
              branches = ", ".join(b for b in info["branches"] if b)
              lines.append(f"*** {repo} ({info['commits']} commits)")
              if branches:
                  lines.append(f"- Branches: {branches}")
              for msg in info["messages"][:5]:
                  lines.append(f"- {msg}")
          if data.get("commits_by_day"):
              lines.append("")
              lines.append("** Commits by Day")
              for day, count in sorted(data["commits_by_day"].items(), key=lambda x: -x[1]):
                  lines.append(f"| {day} | {count} |")
          lines.append("")
          return "\n".join(lines) + "\n"

      def section_desktop(data: dict) -> str:
          if not data:
              return "* Desktop Focus\nActivityWatch not available.\n\n"
          lines = [
              "* Desktop Focus",
              f"- Active: {data.get('active_hours', 0)}h",
              f"- Idle: {data.get('idle_hours', 0)}h",
              "",
              "** Top Applications",
          ]
          for app, dur in data.get("top_apps", []):
              lines.append(f"| {app} | {round(dur / 3600, 1)}h |")
          lines.append("")
          return "\n".join(lines) + "\n"

      def section_editor(data: dict) -> str:
          if not data:
              return "* Editor Activity\nWakapi not available.\n\n"
          lines = [
              "* Editor Activity",
              f"- Total coding time: {data.get('total_hours', 0)}h",
          ]
          if data.get("projects"):
              lines.append("")
              lines.append("** Top Projects")
              for name, hrs in data["projects"]:
                  lines.append(f"| {name} | {hrs}h |")
          if data.get("languages"):
              lines.append("")
              lines.append("** Top Languages")
              for name, hrs in data["languages"]:
                  lines.append(f"| {name} | {hrs}h |")
          lines.append("")
          return "\n".join(lines) + "\n"

      def section_files(data: dict) -> str:
          if not data or not data.get("total"):
              return "* File Changes\nNo file changes recorded.\n\n"
          lines = [
              "* File Changes",
              f"- Total events: {data['total']}",
          ]
          if data.get("by_event"):
              lines.append("- Breakdown: " + ", ".join(f"{k}: {v}" for k, v in data["by_event"].items()))
          if data.get("top_directories"):
              lines.append("")
              lines.append("** Most Active Directories")
              for d, count in data["top_directories"]:
                  lines.append(f"| {d} | {count} |")
          lines.append("")
          return "\n".join(lines) + "\n"

      # ── LLM ────────────────────────────────────────────────────────────

      def ask_llm(summary_text: str) -> str:
          prompt = (
              "You are analysing a developer's weekly activity data.\n\n"
              f"{summary_text}\n\n"
              "Based on this data:\n"
              "1. Identify the main workflows and how time was distributed\n"
              "2. Spot repeated command sequences that could be automated — write shell functions\n"
              "3. Flag any anomalies (unusual hours, high failure rates, context switching)\n"
              "4. Suggest concrete productivity improvements\n\n"
              "Output in org-mode with * headlines and #+begin_src bash blocks.\n"
          )
          for attempt in range(3):
              try:
                  r = requests.post(
                      LLAMA_URL,
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
                  return "* LLM unreachable after 3 attempts\n"
              except Exception as exc:
                  return f"* LLM call failed: {exc}\n"

      # ── Main ────────────────────────────────────────────────────────────

      def main() -> None:
          sessions, shell_stats = load_sessions()
          patterns = mine_patterns(sessions)
          git_data = load_git_activity()
          file_data = load_file_changes()
          aw_data = load_activitywatch()
          wakapi_data = load_wakapi()

          report_parts = [
              f"#+TITLE: Activity Report {datetime.date.today()}\n"
              f"#+DATE: {datetime.datetime.now().isoformat()}\n",
              section_shell(shell_stats, patterns),
              section_git(git_data),
              section_desktop(aw_data),
              section_editor(wakapi_data),
              section_files(file_data),
          ]

          if LLM_ENABLED:
              stats_text = "\n".join(report_parts[1:])
              llm_report = ask_llm(stats_text)
              report_parts.append("* AI Insights\n" + llm_report + "\n")

          REPORT.parent.mkdir(parents=True, exist_ok=True)
          REPORT.write_text("\n".join(report_parts))

      if __name__ == "__main__":
          main()
    '';
  };
in
{
  config = lib.mkIf (cfg.enable && aCfg.enable) (
    lib.mkMerge [
      {
        systemd.user.services.marchyo-tracking-weekly-analysis = {
          description = "Marchyo tracking: weekly activity analysis";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${analysisScript}";
          };
          environment = {
            MARCHYO_DATA_DIR = cfg.dataDir;
            MARCHYO_WAKAPI_PORT = toString cfg.editor.port;
            MARCHYO_LLM_ENABLED = if llmEnabled then "1" else "0";
            MARCHYO_LLAMA_PORT = toString aCfg.port;
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
      }

      (lib.mkIf llmEnabled {
        systemd.services.marchyo-llama-server = {
          description = "llama-server for marchyo tracking analysis";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = "${llamaCppPackage}/bin/llama-server -m ${aCfg.model} --host 127.0.0.1 --port ${toString aCfg.port} -c 8192";
            Restart = "on-failure";
            RestartSec = 5;
            DynamicUser = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            NoNewPrivileges = true;
          };
        };
      })
    ]
  );
}
