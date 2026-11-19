# marchyo.desktop.compositorWatch: the watchdog user unit, the wayland-wm@
# ExecStopPost that keeps the Hyprland log, and the watchdog script.
{ lib, pkgs, ... }:
let
  unit = "marchyo-compositor-watch";
  dropin = "wayland-wm@";
  execStopPost = c: toString (c.systemd.user.services.${dropin}.serviceConfig.ExecStopPost or "");

  # hyprctl answers ok on every third call and fails otherwise, unless
  # STUB_MODE is "fail" (always fails). Calls are counted in $STUB_COUNT.
  stubs = pkgs.writeShellScriptBin "hyprctl" ''
    echo x >>"$STUB_COUNT"
    n=$(wc -l <"$STUB_COUNT")
    [ "''${STUB_MODE:-}" = fail ] && exit 1
    [ $((n % 3)) -eq 0 ]
  '';
in
{
  refs = {
    desktop = {
      eval-compositor-watch-enabled =
        c:
        (c.systemd.user.services ? ${unit})
        && c.systemd.user.services.${unit}.enable
        && c.systemd.user.services.${unit}.wantedBy == [ "graphical-session.target" ]
        && c.systemd.user.services.${unit}.serviceConfig.RestrictAddressFamilies == "AF_UNIX";

      eval-compositor-watch-dropin =
        c:
        lib.hasInfix "-${builtins.storeDir}/" (execStopPost c) && lib.hasInfix "keep-log" (execStopPost c);
    };

    headless.eval-compositor-watch-headless-off = c: !(c.systemd.user.services ? ${unit});

    desktop-off = {
      eval-compositor-watch-disabled = c: !(c.systemd.user.services ? ${unit});
      eval-compositor-watch-disabled-no-dropin = c: !(lib.hasInfix "keep-log" (execStopPost c));
    };
  };

  refConfig.desktop-off.marchyo.desktop.compositorWatch.enable = false;

  checks = {
    eval-compositor-watch-script =
      pkgs.runCommand "eval-compositor-watch-script"
        {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.findutils
            pkgs.gnugrep
            pkgs.util-linux
            stubs
          ];
        }
        ''
          export XDG_RUNTIME_DIR=$PWD/run XDG_STATE_HOME=$PWD/state STUB_COUNT=$PWD/count
          export MARCHYO_COMPOSITOR_WATCH_INTERVAL=0.05 MARCHYO_COMPOSITOR_WATCH_GRACE=1
          export MARCHYO_COMPOSITOR_WATCH_COMM=sleep
          script=${../../modules/nixos/compositor-watch.sh}
          state=$XDG_STATE_HOME/marchyo/hyprland

          # fake <name>: a stand-in compositor with its instance directory.
          fake() {
            rm -rf run state count
            mkdir -p run/hypr/$1
            sleep 1000 &
            pid=$!
            echo $pid >run/hypr/$1/hyprland.lock
            echo "Hyprland test log" >run/hypr/$1/hyprland.log
          }
          expect() {
            local what=$1
            shift
            "$@" || { echo "FAIL: $what" >&2; exit 1; }
          }
          hangs() { find $state -maxdepth 1 -name 'hang-*' 2>/dev/null | wc -l; }

          # Three misses in a row: evidence is written and the process ends.
          fake sig1
          STUB_MODE=fail timeout 5 bash $script 2>err || true
          expect "three probes, no more" test "$(wc -l <count)" = 3
          expect "one hang directory" test "$(hangs)" = 1
          d=$(find $state -maxdepth 1 -name 'hang-*')
          for f in hyprland.log status threads sched; do
            expect "$f saved" test -e $d/$f
          done
          expect "the process was killed" bash -c "! kill -0 $pid 2>/dev/null || grep -q '^State:.Z' /proc/$pid/status"
          expect "the hang is logged" grep -q 'hung' err

          # An answer in between resets the count: never three misses in a row.
          fake sig2
          timeout 2 bash $script 2>err || true
          expect "enough probes ran" test "$(wc -l <count)" -ge 9
          expect "no hang directory while flapping" test "$(hangs)" = 0
          expect "the process lives" kill -0 $pid
          kill $pid

          # No Hyprland: the loop stays quiet and probes nothing.
          rm -rf run state count
          mkdir -p run/hypr
          STUB_MODE=fail timeout 1 bash $script 2>err || true
          expect "no probe" test ! -e count
          expect "no output" test ! -s err
          expect "no hang directory without Hyprland" test "$(hangs)" = 0

          # A lock that names a dead process is not a compositor.
          fake sig3
          kill $pid
          wait $pid || true
          STUB_MODE=fail timeout 1 bash $script 2>err || true
          expect "stale lock ignored" test ! -e count

          # --now skips the probe.
          fake sig4
          bash $script --now 2>err
          expect "no probe with --now" test ! -e count
          expect "evidence with --now" test "$(hangs)" = 1
          bash $script --now 2>err && { echo "FAIL: --now without Hyprland" >&2; exit 1; }
          expect "--now says why" grep -q 'no running Hyprland' err

          touch $out
        '';
  };
}
