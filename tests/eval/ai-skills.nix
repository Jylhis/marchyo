# marchyo.ai.skills and marchyo.ai.crashCapture: defaults, the skill links in
# the three agents' directories, and the crash watcher unit.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;

  system =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.ai.agents = [ "claude-code" ];
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };
  hm = extra: (system extra).config.home-manager.users.testuser;

  check =
    name: ok: detail:
    pkgs.writeText "eval-${name}" (if ok then "pass" else throw "FAIL: ${name}: ${detail}");

  skillNames = [
    "marchyo"
    "marchyo-plugin"
    "diagnose-crash"
  ];
  linked =
    files: dir:
    lib.all (
      n: files ? "${dir}/${n}" && lib.hasSuffix "/share/marchyo/skills/${n}" files."${dir}/${n}".source
    ) skillNames;
  desktop = {
    marchyo.desktop.enable = true;
  };
in
{
  eval-ai-skills-default-follows-agent =
    testNixOSCheck "ai-skills-default-follows-agent" (c: c.marchyo.ai.skills.enable)
      (withTestUser {
        marchyo.ai.agents = [ "codex" ];
      });

  eval-ai-skills-default-off-without-agent = testNixOSCheck "ai-skills-default-off-without-agent" (
    c: !c.marchyo.ai.skills.enable
  ) (withTestUser { });

  eval-ai-skills-installed =
    let
      u = hm { };
    in
    check "ai-skills-installed" (
      linked u.home.file ".claude/skills"
      && linked u.home.file ".codex/skills"
      && linked u.xdg.configFile "opencode/skills"
      && lib.hasSuffix "/share/marchyo/skills" u.home.sessionVariables.MARCHYO_AGENT_SKILLS
    ) "skill links missing in the claude, codex or opencode directory";

  eval-ai-skills-disabled =
    let
      u = hm { marchyo.ai.skills.enable = false; };
    in
    check "ai-skills-disabled" (
      !(u.home.file ? ".claude/skills/marchyo") && !(u.home.sessionVariables ? MARCHYO_AGENT_SKILLS)
    ) "skills installed although marchyo.ai.skills.enable is false";

  eval-ai-crash-capture-default = testNixOSCheck "ai-crash-capture-default" (
    c: c.marchyo.ai.crashCapture.enable
  ) (withTestUser (lib.recursiveUpdate desktop { marchyo.ai.agents = [ "claude-code" ]; }));

  eval-ai-crash-capture-needs-desktop =
    testNixOSCheck "ai-crash-capture-needs-desktop" (c: !c.marchyo.ai.crashCapture.enable)
      (withTestUser {
        marchyo.ai.agents = [ "claude-code" ];
      });

  # The ignore regex reaches the script through a file: Environment= would
  # mangle the backslash, the % and the spaces.
  eval-ai-crash-capture-unit =
    let
      ignore = "^(foo\\.bar|a b|100%)$";
      svc =
        (hm (
          lib.recursiveUpdate desktop {
            marchyo.ai.crashCapture = {
              inherit ignore;
              dedupeSeconds = 120;
            };
          }
        )).systemd.user.services.marchyo-crash-watch;
      env = svc.Service.Environment;
      ignoreEntry = lib.findFirst (lib.hasPrefix "MARCHYO_CRASH_IGNORE_FILE=") null env;
    in
    pkgs.runCommand "eval-ai-crash-capture-unit" { } ''
      ${lib.optionalString (ignoreEntry == null) "echo 'FAIL: no MARCHYO_CRASH_IGNORE_FILE' >&2; exit 1"}
      file=${lib.removePrefix "MARCHYO_CRASH_IGNORE_FILE=" (toString ignoreEntry)}
      printf '%s' ${lib.escapeShellArg ignore} | cmp - "$file"
      ${lib.optionalString (
        !(
          lib.elem "MARCHYO_CRASH_DEDUPE_SECONDS=120" env
          && !(lib.any (lib.hasPrefix "MARCHYO_CRASH_IGNORE=") env)
          && svc.Install.WantedBy == [ "graphical-session.target" ]
          && svc.Service.NoNewPrivileges
          && svc.Service.RestrictAddressFamilies == "AF_UNIX"
          && svc.Service.TasksMax <= 64
        )
      ) "echo ${lib.escapeShellArg "FAIL: unexpected watcher unit: ${builtins.toJSON svc}"} >&2; exit 1"}
      touch $out
    '';

  # The CLI the watcher calls resolves to marchyo-cli, with and without the
  # system-wide CLI: a shim named marchyo on its PATH would exec itself forever.
  eval-ai-crash-capture-cli =
    let
      watcherFor =
        cli:
        lib.head (
          lib.toList
            (hm (lib.recursiveUpdate desktop { marchyo.cli.enable = cli; }))
            .systemd.user.services.marchyo-crash-watch.Service.ExecStart
        );
    in
    pkgs.runCommand "eval-ai-crash-capture-cli" { } ''
      for script in ${watcherFor true} ${watcherFor false}; do
        path=$(sed -n 's/^export PATH="\(.*\):\$PATH"$/\1/p' "$script")
        found=$(PATH=$path type -P marchyo)
        [ "$(readlink -f "$found")" = "$(readlink -f ${(system { }).pkgs.marchyo-cli}/bin/marchyo)" ] || {
          echo "FAIL: $script resolves marchyo to $found" >&2
          exit 1
        }
      done
      touch $out
    '';

  # The watcher script against stub journalctl, notify-send and marchyo.
  eval-ai-crash-watch-script =
    let
      stubs = pkgs.symlinkJoin {
        name = "crash-watch-stubs";
        paths = [
          (pkgs.writeShellScriptBin "journalctl" "exec cat \"$STUB_JOURNAL\"")
          (pkgs.writeShellScriptBin "notify-send" ''
            printf '%s|' "$@" >>"$STUB_NOTIFY"
            echo >>"$STUB_NOTIFY"
            sleep "''${STUB_SLEEP:-0}"
            echo "''${STUB_ACTION:-}"
          '')
          (pkgs.writeShellScriptBin "marchyo" ''
            printf '%s|' "$@" >>"$STUB_MARCHYO"
            echo >>"$STUB_MARCHYO"
          '')
        ];
      };
    in
    pkgs.runCommand "eval-ai-crash-watch-script"
      {
        nativeBuildInputs = [
          pkgs.bash
          pkgs.coreutils
          pkgs.gnugrep
          pkgs.jq
          stubs
        ];
      }
      ''
        export STUB_NOTIFY=$PWD/notify STUB_MARCHYO=$PWD/marchyo.log STUB_JOURNAL=$PWD/journal
        unit=systemd-coredump@0-1-0.service

        # entry <unit> <uid> <comm> <exe> <pid> [timestamp]
        entry() {
          jq -nc --arg u "$1" --arg uid "$2" --arg c "$3" --arg e "$4" --arg p "$5" \
            --arg t "''${6:-1762345678901234}" \
            '{_SYSTEMD_UNIT: $u, _UID: $uid, COREDUMP_COMM: $c, COREDUMP_EXE: $e, COREDUMP_PID: $p,
              COREDUMP_SIGNAL_NAME: "SIGSEGV", COREDUMP_TIMESTAMP: $t}'
        }
        # run: the journal on stdin; leaves notify and marchyo.log behind
        run() {
          rm -f notify marchyo.log
          touch notify marchyo.log
          cat >journal
          bash ${../../modules/home/crash-watch.sh} 2>err || { cat err >&2; return 1; }
        }
        expect() { # <description> <test command...>
          local what=$1
          shift
          "$@" || { echo "FAIL: $what" >&2; echo "--- notify" >&2; cat notify >&2; echo "--- marchyo" >&2; cat marchyo.log >&2; exit 1; }
        }
        count() { wc -l <"$1" | tr -d ' '; }

        # A message any process of this user could write, a foreign user's dump, a real one.
        { entry app.service "$UID" forged /bin/forged 11
          entry "$unit" 0 root-prog /bin/rootprog 12
          entry "$unit" "$UID" real /bin/real 13; } | run
        expect "only the genuine dump is offered" test "$(count notify)" = 1
        expect "the genuine dump is named" grep -qF 'Process crashed: real|' notify

        # A name that looks like an option reaches the CLI after --, with the timestamp.
        entry "$unit" "$UID" --help "" 14 99887766 | STUB_ACTION=diagnose run
        expect "agent crash gets -- first" grep -qxF 'agent|crash|--|14|--help|-|SIGSEGV|99887766|' marchyo.log

        # A non-numeric PID is dropped.
        entry "$unit" "$UID" prog /bin/prog '1; true' | run
        expect "no offer for a non-numeric PID" test "$(count notify)" = 0

        # The same program is announced once per window.
        { entry "$unit" "$UID" a /bin/dup 21; entry "$unit" "$UID" a /bin/dup 22; } | run
        expect "dedupe" test "$(count notify)" = 1

        # A burst of distinct programs is cut at three a minute.
        for i in 1 2 3 4 5 6; do entry "$unit" "$UID" p /bin/prog$i 3$i; done | run
        expect "rate limit" test "$(count notify)" = 3

        # Open notifications are capped.
        for i in 1 2 3 4 5 6 7 8; do entry "$unit" "$UID" p /bin/prog$i 4$i; done |
          MARCHYO_CRASH_MAX_PER_MINUTE=100 STUB_SLEEP=1 run
        expect "concurrent offers" test "$(count notify)" = 5

        # The shell renders notification markup.
        entry "$unit" "$UID" '<b>x&y' "" 51 | run
        expect "markup escaped" grep -qF 'Process crashed: &lt;b&gt;x&amp;y|' notify
        expect "no raw markup" bash -c '! grep -qF "<b>" notify'

        # The ignore pattern keeps its backslash; an invalid one is reported and dropped.
        printf '%s' '^foo\.bar$' >ignore
        { entry "$unit" "$UID" c /bin/foo.bar 61; entry "$unit" "$UID" c /bin/fooxbar 62; } |
          MARCHYO_CRASH_IGNORE_FILE=$PWD/ignore run
        expect "regex honoured" grep -qF 'Process crashed: fooxbar|' notify
        expect "ignored program skipped" bash -c '! grep -qF "foo.bar" notify'
        printf '%s' '(' >ignore
        entry "$unit" "$UID" c /bin/real 63 | MARCHYO_CRASH_IGNORE_FILE=$PWD/ignore run
        expect "invalid regex logged once" test "$(grep -c 'invalid' err)" = 1
        expect "invalid regex ignores nothing" test "$(count notify)" = 1

        touch $out
      '';

  eval-ai-crash-capture-disabled =
    let
      u = hm (lib.recursiveUpdate desktop { marchyo.ai.crashCapture.enable = false; });
    in
    check "ai-crash-capture-disabled" (
      !(u.systemd.user.services ? marchyo-crash-watch)
    ) "watcher defined although marchyo.ai.crashCapture.enable is false";
}
